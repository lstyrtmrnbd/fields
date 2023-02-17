(require hyrule [defmain])

(import sys [exit])
(import pygame :as pg)
(import OpenGL.GL *)
(import OpenGL.GL [shaders])
(import OpenGL.arrays *)
(import OpenGL.arrays [vbo])
(import numpy [array])

(setv geom (array [[-1.0  1.0 0.0]
                   [-1.0 -1.0 0.0]
                   [ 1.0 -1.0 0.0]
                   [ 1.0 -1.0 0.0]
                   [ 1.0  1.0 0.0]
                   [-1.0  1.0 0.0]]))

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
  (setv surf (pygame.image.load filename))
  (setv image (pygame.image.tostring surf "RGBA" 1))
  (setv [ix iy] (surf.get_rect.size))          
  (setv texid (glGenTextures 1))
  (glBindTexture GL_TEXTURE_2D texid)
  (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MIN_FILTER GL_LINEAR)
  (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MAG_FILTER GL_LINEAR)
  (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_S GL_CLAMP_TO_EDGE)
  (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_T GL_CLAMP_TO_EDGE)
  (glTexImage2D GL_TEXTURE_2D 0 GL_RGBA ix iy 0 GL_RGBA GL_UNSIGNED_BYTE image)
  ;; unbind texture
  texid)

(defn shader-load [vertfile fragfile]
  "Takes two filenames and returns a compiled shaderid"
  (with [vertsrc (open vertfile "r")
         fragsrc (open fragfile "r")]
    (let [vtx (shaders.compileShader (vertsrc.read) GL_VERTEX_SHADER)
          frg (shaders.compileShader (fragsrc.read) GL_FRAGMENT_SHADER)]
      (shaders.compileProgram vtx frg))))

(defn main []
  "夜露死苦"
  (pg.init)
  (pg.display.gl_set_attribute pg.GL_CONTEXT_FLAGS pg.GL_CONTEXT_DEBUG_FLAG)
  (pg.display.set_mode [1280 720] (| pg.OPENGL pg.DOUBLEBUF))
  (pg.display.set_caption "夜露死苦")
  (gl-init)
  (setv shader (shader-load "simple.vert" "simple.frag"))
  (setv quadbuffer (vbo.VBO geom))
  (shaders.glUseProgram shader)
  (quadbuffer.bind)
  (while True
    (lfor event (pg.event.get)
          (dispatch event))
    (glVertexPointerf quadbuffer)
    (glDrawArrays GL_TRIANGLES 0 9)
    (quadbuffer.unbind)
    (shaders.glUseProgram 0)
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
