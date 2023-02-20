(require hyrule [defmain])

(import PyTexturePacker [Packer])

(defn main []
  (. (Packer.create :max_width 4096
                    :max_height 4096
                    :bg_color 0xffffff00
                    :atlas_format "json"
                    :enable_rotated False
                    :force_square True)
     (pack "../tex/" "texpck%d")))

(defmain []
  (main))
