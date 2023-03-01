(require hyrule [defmain setv+])

(import sys [exit])
(import time [perf_counter_ns :as timer])
(import pygame :as pg)
(import OpenGL.GL *)
(import OpenGL.GL [shaders])
(import OpenGL.arrays *)
(import OpenGL.arrays [vbo])
(import numpy [array])
(import ctypes [sizeof c_void_p c_float])
(import json)
(import glm [mat4
             vec3
             identity :as idmat
             radians
             perspective
             lookAt :as lookat])

(defn debug-callback [source msg_type msg_id severity length raw user]
  (print "debug" source msg_type msg_id severity (cut raw 0 length)))

(defn gl-init []
  ;; (glEnable GL_DEBUG_OUTPUT)
  ;; (glDebugMessageCallback (GLDEBUGPROC debug-callback) None)
  (print (+ "OpenGL @" (bytes.decode (glGetString GL_VERSION))))
  (print (+ "Shading language @" (bytes.decode (glGetString GL_SHADING_LANGUAGE_VERSION))))
  (print (+ "Context flags " (str (glGetInteger GL_CONTEXT_FLAGS))))
  (glClearColor 0.9 0.7 0.3 1.0)
  (glEnable GL_DEPTH_TEST)
  (glEnable GL_CULL_FACE)
  (glCullFace GL_BACK)
  (glEnable GL_BLEND)
  (glEnable GL_TEXTURE_2D)
  (glBlendFunc GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA))

(defn tex-load [filename]
  "Load filename to texture and return texid"
  (setv surf (pg.image.load filename))
  (setv image (pg.image.tostring surf "RGBA" 1))
  (setv [ix iy] (. (surf.get_rect) size))
  (setv texid (glGenTextures 1))
  (glBindTexture GL_TEXTURE_2D texid)
  (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MIN_FILTER GL_LINEAR)
  (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MAG_FILTER GL_LINEAR)
  (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_S GL_CLAMP_TO_EDGE)
  (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_T GL_CLAMP_TO_EDGE)
  (glTexImage2D GL_TEXTURE_2D 0 GL_RGBA ix iy 0 GL_RGBA GL_UNSIGNED_BYTE image)
  ;; unbind texture if thou wilt
  texid)

(defn tex-atlas-load [fileprefix]
  "Load image and accompanying atlas"
  [(tex-load (+ fileprefix ".png"))
   (with [atlas (open (+ fileprefix ".json"))]
     (json.load atlas))])

(defn parse-tex-coords [iw ih x y w h]
  "Given frame description values, return texcoords normalized to [0.0 1.0]"
  [(/ x iw) (/ y ih) (/ (+ x w) iw) (/ (+ y h) ih)])

(defn parse-atlas [atlas]
  "Parse atlas into texcoords array and texnames array"
  (setv+ {iw "w" ih "h"} (get (get atlas "meta") "size"))
  (let [zipped ; extract info for both lists in one pass
        (lfor key (get atlas "frames")
              :setv frame (get (get (get atlas "frames") key) "frame")
              #(key [(get frame "x") (get frame "y") (get frame "w") (get frame "h")]))]
    (setv [texnames frameinfo] (zip #* zipped)) ; unzip tuples
    [(lfor frame (list frameinfo)
           :setv [x y w h] frame
           (parse-tex-coords iw ih x y w h))
     (list texnames)]))

(defn shader-load [vertfile fragfile]
  "Takes two filenames and returns a compiled shaderid"
  (with [vertsrc (open vertfile "r")
         fragsrc (open fragfile "r")]
    (let [vtx (shaders.compileShader (vertsrc.read) GL_VERTEX_SHADER)
          frg (shaders.compileShader (fragsrc.read) GL_FRAGMENT_SHADER)]
      (shaders.compileProgram vtx frg))))

(defn set-up-buffer [vbo
                     shader
                     location-name
                     location-size
                     [divisor 0]
                     [gl-type GL_FLOAT]]
  "Give basics to establish attribute, fill buffer, and return location in shader"
  (with [vbo]
    (let [location (glGetAttribLocation shader location-name)]
      (glEnableVertexAttribArray location)
      (glVertexAttribPointer location location-size gl-type False 0 (c_void_p 0))
      (glVertexAttribDivisor location divisor)
      location)))

(defn set-up-matrix [vbo
                     shader
                     location-name
                     [divisor 0]
                     [gl-type GL_FLOAT]
                     [type-size (sizeof c_float)]]
  "Configure 4 contiguous locations for 4x4 matrices buffer"
  (with [vbo]
    (let [location (glGetAttribLocation shader location-name)
          stride (* type-size 4 4)]
      (for [i (range 4)]
        (glEnableVertexAttribArray (+ location i))
        (glVertexAttribPointer (+ location i) 4 gl-type False stride (c_void_p (* type-size i 4)))
        (glVertexAttribDivisor (+ location i) divisor)))))

(setv quad (array [[-1.0  1.0 0.0]
                   [-1.0 -1.0 0.0]
                   [ 1.0 -1.0 0.0]
                   [ 1.0 -1.0 0.0]
                   [ 1.0  1.0 0.0]
                   [-1.0  1.0 0.0]]))

; indices into texcoord array
(setv texindices (array [[0 1]
                         [0 3]
                         [2 3]
                         [2 3]
                         [2 1]
                         [0 1]]))

(setv DEFAULT_TEX "texpck/texpck0")
(setv [texid atlas] (tex-atlas-load DEFAULT_TEX))
(setv [texcoords texnames] (parse-atlas atlas))

(setv texcoords (array texcoords))
(setv initial-tex-idxs (array [0 1]))
(setv initial-colors (array [[0.9 0.3 0.3 1.0] [0.9 0.3 0.3 1.0]]))
(setv initial-models (array [(array (idmat mat4)) (array (idmat mat4))]))

(defn make-vao [shader]
  (setv vao (glGenVertexArrays 1))
  (glBindVertexArray vao)
  (setv pos-vbo (vbo.VBO quad)) ; verts
  (setv pos-loc (set-up-buffer pos-vbo shader "position" 4))
  (setv idx-vbo (vbo.VBO texindices)); idx into single texcoord array
  (setv idx-loc (set-up-buffer idx-vbo shader "texIdx" 2 0 GL_INT))
  ;; this needs to go in a texture and get texelfetched in vtx shader
  ;; (setv tex-coord-vbo (vbo.VBO texcoords)) ; all texcoords per atlas
  ;; (setv tex-coord-loc (set-up-buffer tex-coord-vbo shader "atlasCoords" 4))
  (setv tex-index-vbo (vbo.VBO initial-tex-idxs)) ; idx into atlas
  (setv tex-index-loc (set-up-buffer tex-index-vbo shader "atlasIdx" 1 1 GL_INT))
  (setv colors-vbo (vbo.VBO initial-colors)) ; funny color
  (setv colors-loc (set-up-buffer colors-vbo shader "colors" 4 1 GL_FLOAT))
  (setv models-vbo (vbo.VBO initial-models)) ; model matrices
  (setv models-loc (set-up-matrix models-vbo shader "model" 1)) ; naisu desu ne
  [vao
   pos-vbo pos-loc
   tex-coord-vbo tex-coord-loc
   tex-index-vbo tex-index-loc
   colors-vbo colors-loc
   models-vbo models-loc])

(defn main []
  "夜露死苦"
  (pg.init)
  (pg.display.gl_set_attribute pg.GL_CONTEXT_FLAGS pg.GL_CONTEXT_DEBUG_FLAG)
  (pg.display.set_mode [1280 720] (| pg.OPENGL pg.DOUBLEBUF))
  (pg.display.set_caption "夜露死苦")
  (gl-init)
  (setv shader (shader-load "simple.vert" "simple.frag"))
  (shaders.glUseProgram shader)
  (setv [vao
         pos-vbo pos-loc
         tex-coord-vbo tex-coord-loc
         tex-index-vbo tex-index-loc
         colors-vbo colors-loc
         models-vbo models-loc] (make-vao shader))
  (setv time (timer))
  (setv target (vec3 0.0))
  (setv position (vec3 0.0 0.0 3.0))
  (setv projection (perspective (radians 60.0) (/ 16.0 9.0) 0.1 100.0))
  (setv view (lookat position target (vec3 0.0 1.0 0.0)))
  (setv view-projection (* projection view))
  (setv view-proj-loc (glGetUniformLocation shader "viewProjection"))
  (setv texs-loc (glGetUniformLocation shader "texs"))
  (while True
    (lfor event (pg.event.get)
          (dispatch event))
    (glDrawArrays GL_TRIANGLES 0 9)
    (pg.display.flip)))

(defn dispatch [event]
  (print event)
  (when (= event.type pg.QUIT)
    (exit))
  (when (and (= event.type pg.KEYUP)
             (= event.key pg.K_ESCAPE))
    (exit)))

(defmain []
  (main))
