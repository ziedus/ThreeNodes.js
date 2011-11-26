define [
  'jQuery',
  'Underscore', 
  'Backbone',
  "text!templates/node.tmpl.html",
  "order!libs/jquery.tmpl.min",
  "order!libs/jquery.contextMenu",
  "order!libs/jquery-ui/js/jquery-ui-1.9m6.min",
  'order!threenodes/core/NodeFieldRack',
  'order!threenodes/utils/Utils',
], ($, _, Backbone, _view_node_template) ->
  class ThreeNodes.nodes.types.Three.Object3D extends ThreeNodes.NodeBase
    set_fields: =>
      super
      @auto_evaluate = true
      @ob = new THREE.Object3D()
      @rack.addFields
        inputs:
          "children": {type: "Array", val: []}
          "position": {type: "Vector3", val: new THREE.Vector3()}
          "rotation": {type: "Vector3", val: new THREE.Vector3()}
          "scale": {type: "Vector3", val: new THREE.Vector3(1, 1, 1)}
          "doubleSided": false
          "visible": true
          "castShadow": false
          "receiveShadow": false
        outputs:
          "out": {type: "Any", val: @ob}
      @vars_shadow_options = ["castShadow", "receiveShadow"]
      @shadow_cache = @create_cache_object(@vars_shadow_options)
  
    compute: =>
      @apply_fields_to_val(@rack.node_fields.inputs, @ob, ['children'])
      childs_in = @rack.get("children").get()
      
      # no connections mean no children
      if @rack.get("children").connections.length == 0 && @ob.children.length != 0
        @ob.remove(@ob.children[0]) while @ob.children.length > 0
      
      # remove old childs
      for child in @ob.children
        ind = childs_in.indexOf(child)
        if child && ind == -1 && child
          #console.log "object remove child"
          #console.log @ob
          @ob.removeChild(child)
      
      #add new childs
      for child in childs_in
        ind = @ob.children.indexOf(child)
        if ind == -1
          #console.log "object add child"
          #console.log @ob
          @ob.addChild(child)
      
      @rack.set("out", @ob)
  
  class ThreeNodes.nodes.types.Three.Scene extends ThreeNodes.nodes.types.Three.Object3D
    set_fields: =>
      super
      @ob = new THREE.Scene()
      current_scene = @ob
  
    apply_children: =>
      # no connections means no children
      if @rack.get("children").connections.length == 0 && @ob.children.length != 0
        @ob.remove(@ob.children[0]) while @ob.children.length > 0
        return true
      
      childs_in = @rack.get("children").get()
      # remove old childs
      for child in @ob.children
        ind = childs_in.indexOf(child)
        if child && ind == -1 && child instanceof THREE.Light == false
          #console.log "scene remove child"
          #console.log @ob
          @ob.remove(child)
          
      for child in @ob.children
        ind = childs_in.indexOf(child)
        if child && ind == -1 && child instanceof THREE.Light == true
          @ob.remove(child)
          
      #add new childs
      for child in childs_in
        if child instanceof THREE.Light == true
          ind = @ob.children.indexOf(child)
          if ind == -1
            @ob.add(child)
            ThreeNodes.rebuild_all_shaders()
        else
          ind = @ob.children.indexOf(child)
          if ind == -1
            #console.log "scene add child"
            #console.log @ob
            @ob.add(child)
  
    compute: =>
      @apply_fields_to_val(@rack.node_fields.inputs, @ob, ['children', 'lights'])
      @apply_children()
      @rack.set("out", @ob)
  
  class ThreeNodes.nodes.types.Three.Mesh extends ThreeNodes.nodes.types.Three.Object3D
    set_fields: =>
      super
      @rack.addFields
        inputs:
          "geometry": {type: "Any", val: new THREE.CubeGeometry( 200, 200, 200 )}
          "material": {type: "Any", val: new THREE.MeshBasicMaterial({color: 0xff0000})}
          "overdraw": false
      @ob = new THREE.Mesh(@rack.get('geometry').get(), @rack.get('material').get())
      @geometry_cache = false
      @material_cache = false
      @compute()
    
    rebuild_geometry: =>
      field = @rack.get('geometry')
      if field.connections.length > 0
        geom = field.connections[0].from_field.node
        geom.cached = []
        geom.compute()
      else
        @rack.get('geometry').set(new THREE.CubeGeometry( 200, 200, 200 ))
      
    compute: =>
      needs_rebuild = false
      
      if @input_value_has_changed(@vars_shadow_options, @shadow_cache)
        needs_rebuild = true
      
      if @material_cache != @rack.get('material').get().id
        # let's trigger a geometry rebuild so we have the appropriate buffers set
        @rebuild_geometry()
      
      if @geometry_cache != @rack.get('geometry').get().id || @material_cache != @rack.get('material').get().id || needs_rebuild
        @ob = new THREE.Mesh(@rack.get('geometry').get(), @rack.get('material').get())
        @geometry_cache = @rack.get('geometry').get().id
        @material_cache = @rack.get('material').get().id
      
      @apply_fields_to_val(@rack.node_fields.inputs, @ob, ['children', 'geometry', 'material'])
      @shadow_cache = @create_cache_object(@vars_shadow_options)
      
      if needs_rebuild == true
        ThreeNodes.rebuild_all_shaders()
      
      @rack.set("out", @ob)
  
  class ThreeNodes.nodes.types.Three.ParticleSystem extends ThreeNodes.nodes.types.Three.Object3D
    set_fields: =>
      super
      @rack.addFields
        inputs:
          "geometry": {type: "Any", val: new THREE.CubeGeometry( 200, 200, 200 )}
          "material": {type: "Any", val: new THREE.ParticleBasicMaterial()}
      @ob = new THREE.ParticleSystem(@rack.get('geometry').get(), @rack.get('material').get())
      @geometry_cache = false
      @material_cache = false
      @compute()
    
    rebuild_geometry: =>
      field = @rack.get('geometry')
      if field.connections.length > 0
        geom = field.connections[0].from_field.node
        geom.cached = []
        geom.compute()
      else
        @rack.get('geometry').set(new THREE.CubeGeometry( 200, 200, 200 ))
      
    compute: =>
      needs_rebuild = false
      
      if @material_cache != @rack.get('material').get().id
        # let's trigger a geometry rebuild so we have the appropriate buffers set
        @rebuild_geometry()
      
      if @geometry_cache != @rack.get('geometry').get().id || @material_cache != @rack.get('material').get().id || needs_rebuild
        @ob = new THREE.ParticleSystem(@rack.get('geometry').get(), @rack.get('material').get())
        @geometry_cache = @rack.get('geometry').get().id
        @material_cache = @rack.get('material').get().id
      
      @apply_fields_to_val(@rack.node_fields.inputs, @ob, ['children', 'geometry', 'material'])
      
      if needs_rebuild == true
        ThreeNodes.rebuild_all_shaders()
      
      @rack.set("out", @ob)
  
  class ThreeNodes.nodes.types.Three.Camera extends ThreeNodes.NodeBase
    set_fields: =>
      super
      @ob = new THREE.PerspectiveCamera(75, 800 / 600, 1, 10000)
      @rack.addFields
        inputs:
          "fov": 50
          "aspect": 1
          "near": 0.1
          "far": 2000
          "position": {type: "Vector3", val: new THREE.Vector3()}
          "target": {type: "Vector3", val: new THREE.Vector3()}
          "useTarget": false
        outputs:
          "out": {type: "Any", val: @ob}
  
    compute: =>
      @apply_fields_to_val(@rack.node_fields.inputs, @ob, ['target'])
      @ob.lookAt(@rack.get("target").get())
      @rack.set("out", @ob)
  
  class ThreeNodes.nodes.types.Three.Texture extends ThreeNodes.NodeBase
    set_fields: =>
      super
      @ob = false
      @cached = false
      @rack.addFields
        inputs:
          "image": {type: "String", val: false}
        outputs:
          "out": {type: "Any", val: @ob}
  
    compute: =>
      current = @rack.get("image").get()
      if current && current != ""
        if @cached == false || ($.type(@cached) == "object" && @cached.constructor == THREE.Texture && @cached.image.attributes[0].nodeValue != current)
          #@ob = new THREE.Texture(current)
          @ob = new THREE.ImageUtils.loadTexture(current)
          console.log "new texture"
          console.log @ob
          @cached = @ob
          
      @rack.set("out", @ob)
      
  class ThreeNodes.nodes.types.Three.WebGLRenderer extends ThreeNodes.NodeBase
    set_fields: =>
      super
      @auto_evaluate = true
      @preview_mode = true
      @creating_popup = false
      @ob = ThreeNodes.Webgl.current_renderer
      @width = 0
      @height = 0
      $("body").append("<div id='webgl-window'></div>")
      @webgl_container = $("#webgl-window")
      @rack.addFields
        inputs:
          "width": 800
          "height": 600
          "scene": {type: "Scene", val: new THREE.Scene()}
          "camera": {type: "Camera", val: new THREE.PerspectiveCamera(75, 800 / 600, 1, 10000)}
          "bg_color": {type: "Color", val: new THREE.Color(0, 0, 0)}
          "postfx": {type: "Array", val: []}
          "shadowCameraNear": 3
          "shadowCameraFar": 3000
          "shadowMapWidth": 512
          "shadowMapHeight": 512
          "shadowMapEnabled": false
          "shadowMapSoft": true
      
      @rack.get("camera").val.position.z = 1000
      @win = false
      @apply_size()
      @old_bg = false
      @apply_bg_color()
      self = this
      @webgl_container.click (e) ->
        self.create_popup_view()
    
    create_popup_view: ->
      @preview_mode = false
      @creating_popup = true
      
      @win = window.open('', 'win' + @nid, "width=800,height=600,scrollbars=false,location=false,status=false,menubar=false")
      $("body", $(@win.document)).append( @ob.domElement )
      $("*", $(@win.document)).css
        padding: 0
        margin: 0
      @apply_bg_color(true)
      @apply_size(true)
    
    create_preview_view: ->
      @preview_mode = true
      @webgl_container.append( @ob.domElement )
      @apply_bg_color(true)
      @apply_size(true)
    
    apply_bg_color: (force_refresh = false) ->
      new_val = @rack.get('bg_color').get().getContextStyle()
      
      if @old_bg == new_val && force_refresh == false
        return false
      
      @ob.setClearColor( @rack.get('bg_color').get(), 1 )
      @webgl_container.css
        background: new_val
      
      if @win
        $(@win.document.body).css
          background: new_val
      
      @old_bg = new_val
    
    apply_size: (force_refresh = false) =>
      w = @rack.get('width').get()
      h = @rack.get('height').get()
      dw = w
      dh = h
      if @win == false
        maxw = 220
        r = w / h
        dw = maxw
        dh = dw / r
      if dw != @width || dh != @height || force_refresh
        @ob.setSize(dw, dh)
      @width = dw
      @height = dh
    
    apply_post_fx: =>
      # work on a copy of the incoming array
      fxs = @rack.get("postfx").get().slice(0)
      # 1st pass = rendermodel, last pass = screen
      fxs.unshift ThreeNodes.Webgl.renderModel
      fxs.push ThreeNodes.Webgl.effectScreen
      ThreeNodes.Webgl.composer.passes = fxs
      
    add_renderer_to_dom: =>
      if @preview_mode && $("canvas", @webgl_container).length == 0
        @create_preview_view()
      if @preview_mode == false && @win == false
        @create_popup_view()
    
    compute: =>
      # help fix asynchronous bug with firefox when opening popup
      if @creating_popup == true && !@win
        return
      
      @creating_popup = false
      if @win != false
        if @win.closed && @preview_mode == false
          @preview_mode = true
          @win = false
      if !@context.testing_mode
        @add_renderer_to_dom()
      
      @apply_size()
      @apply_bg_color()
      @apply_fields_to_val(@rack.node_fields.inputs, @ob, ['width', 'height', 'scene', 'camera', 'bg_color', 'postfx'])
      ThreeNodes.Webgl.current_camera = @rack.get("camera").get()
      ThreeNodes.Webgl.current_scene = @rack.get("scene").get()
      
      @apply_post_fx()
      @ob.clear()
      ThreeNodes.Webgl.renderModel.scene = ThreeNodes.Webgl.current_scene
      ThreeNodes.Webgl.renderModel.camera = ThreeNodes.Webgl.current_camera
      ThreeNodes.Webgl.composer.renderer = ThreeNodes.Webgl.current_renderer
      ThreeNodes.Webgl.composer.render(0.05)