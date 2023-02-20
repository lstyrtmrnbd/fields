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
             identity
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

(defn parse-atlas [atlas]
  "Parse atlas into texcoords array and texnames array"
  (setv+ {w "w" h "h"} (get (get atlas "meta") "size"))
  (let [zipped ; extract info for both lists in one iteration
        (lfor key (get atlas "frames")
              :setv frame (get (get (get atlas "frames") key) "frame")
              #(key [(get frame "x") (get frame "y") (get frame "w") (get frame "h")]))]
    (setv [texnames texcoords] (zip #* zipped)) ; unzip tuples
    [(list texcoords) (list texnames)]))

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
  "Give basics to establish attribute, fill buffer, and return location"
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

(setv DEFAULT_TEX "texpck/texpck0")
(setv [texid atlas] (tex-atlas-load DEFAULT_TEX))
(setv [texcoords texnames] (parse-atlas atlas))

(setv texcoords (array texcoords))
(setv initial-tex-idxs (array [0 1]))
(setv initial-colors (array [[0.9 0.3 0.3 1.0] [0.9 0.3 0.3 1.0]]))
(setv initial-models (array [(array (identity mat4)) (array (identity mat4))]))

(defn make-vao [shader]
  (setv vao (glGenVertexArrays 1))
  (glBindVertexArray vao)
  (setv pos-vbo (vbo.VBO quad)) ; fixed forever
  (setv pos-loc (set-up-buffer pos-vbo shader "position" 4))
  (setv tex-coord-vbo (vbo.VBO texcoords)) ; fixed per tex atlas
  (setv tex-coord-loc (set-up-buffer tex-coord-vbo shader "texCoord" 4))
  (setv tex-index-vbo (vbo.VBO initial-tex-idxs)) ; varies
  (setv tex-index-loc (set-up-buffer tex-index-vbo shader "texIndex" 4 1 GL_INT))
  (setv colors-vbo (vbo.VBO initial-colors)) ; varies
  (setv colors-loc (set-up-buffer colors-vbo shader "colors" 1 GL_FLOAT 4))
  (setv models-vbo (vbo.VBO initial-models)) ; varies
  (setv models-loc (set-up-matrix models-vbo shader "model" 1)) ; naisu desu ne
  [vao
   pos-vbo pos-loc
   tex-coord-vbo tex-coord-loc
   tex-index-vbo tex-index-loc
   colors-vbo colors-loc
   models-vbo models-locs])

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
         models-vbo models-locs] (make-vao shader))
  (setv time (timer))
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
