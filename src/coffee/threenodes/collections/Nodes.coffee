define [
  'jQuery',
  'Underscore', 
  'Backbone',
  'order!threenodes/models/Node',
  'order!threenodes/nodes/Base',
  'order!threenodes/nodes/Conditional',
  'order!threenodes/nodes/Geometry',
  'order!threenodes/nodes/Lights',
  'order!threenodes/nodes/Materials',
  'order!threenodes/nodes/Math',
  'order!threenodes/nodes/PostProcessing',
  'order!threenodes/nodes/Three',
  'order!threenodes/nodes/Utils',
  'order!threenodes/nodes/Spread',
  'order!threenodes/nodes/Particle',
  'order!threenodes/nodes/Group',
  'order!threenodes/collections/Connections',
], ($, _, Backbone) ->
  "use strict"
  class ThreeNodes.NodeGraph extends Backbone.Collection
    
    initialize: (models, options) =>
      @connections = new ThreeNodes.ConnectionsCollection()
      self = this
      # save material nodes in an array so they can be quickly rebuild
      @materials = []
      
      @connections.bind "add", (connection) ->
        self.trigger "nodeslist:rebuild", self
      
      @bind "remove", (node) =>
        indx = @materials.indexOf(node)
        if indx != -1
          @materials.splice(indx, 1)
        self.trigger "nodeslist:rebuild", self
      
      @bind "RebuildAllShaders", () =>
        for node in @materials
          node.rebuildShader()
      
      @connections.bind "remove", (connection) ->
        self.trigger "nodeslist:rebuild", self
      
      @bind "add", (node) ->
        if node.is_material && node.is_material == true
          @materials.push(node)
        
        self.trigger "nodeslist:rebuild", self
            
      @bind "createConnection", (field1, field2) =>
        @connections.create
          from_field: field1
          to_field: field2
    
    clearWorkspace: () =>
      @removeAllConnections()
      @removeAll()
      $("#webgl-window canvas").remove()
      @materials = []
      return this
    
    bindTimelineEvents: (timeline) =>
      if @timeline
        @timeline.off("trackRebuild", @showNodesAnimation)
        @timeline.off("startSound", @startSound)
        @timeline.off("stopSound", @stopSound)
      console.log "binding timeline"
      @timeline = timeline
      @timeline.on("trackRebuild", @showNodesAnimation)
      @timeline.on("startSound", @startSound)
      @timeline.on("stopSound", @stopSound)
    
    create_node: (options) =>
      opt = options
      if $.type(opt) == "string"
        opt = {type: opt}
      
      opt.timeline = @timeline
      
      if !ThreeNodes.nodes[opt.type]
        console.error("Node type doesn't exists: " + opt.type)
      
      n = new ThreeNodes.nodes[opt.type](opt)
      @add(n)
      n
    
    render: () =>
      invalidNodes = {}
      terminalNodes = {}
      
      for node in @models
        if node.has_out_connection() == false || node.auto_evaluate || node.delays_output
          terminalNodes[node.attributes["nid"]] = node
        invalidNodes[node.attributes["nid"]] = node
      
      evaluateSubGraph = (node) ->
        upstreamNodes = node.getUpstreamNodes()
        for upnode in upstreamNodes
          if invalidNodes[upnode.attributes["nid"]] && !upnode.delays_output
            evaluateSubGraph(upnode)
        if node.dirty || node.auto_evaluate
          node.compute()
          node.dirty = false
          node.rack.setFieldInputUnchanged()
        
        delete invalidNodes[node.attributes["nid"]]
        true
      
      for nid of terminalNodes
        if invalidNodes[nid]
          evaluateSubGraph(terminalNodes[nid])
      true
    
    createConnectionFromObject: (connection) =>
      from_node = @getNodeByNid(connection.from_node.toString())
      from = from_node.rack.node_fields.outputs[connection.from.toString()]
      to_node = @getNodeByNid(connection.to_node.toString())
      to = to_node.rack.node_fields.inputs[connection.to.toString()]
      # if a field is missing try to switch from/to
      if !from || !to
        tmp = from_node
        from_node = to_node
        to_node = tmp
        from = from_node.rack.node_fields.outputs[connection.to.toString()]
        to = to_node.rack.node_fields.inputs[connection.from.toString()]
      
      c = @connections.create
          from_field: from
          to_field: to
          cid: connection.id
      
      c
    
    renderAllConnections: () =>
      @connections.render()
    
    removeSelectedNodes: () ->
      $(".node.ui-selected").each () ->
        $(this).data("object").remove()
      return true
    
    onGroupSelected: () =>
      # Get the average position of selected nodes
      min_x = 0
      min_y = 0
      max_x = 0
      max_y = 0
      
      # Selected nodes jquery selector
      $selected = $(".node.ui-selected")
      
      # Stop directly if there is no node selected
      if $selected.length < 1
        return false
      
      # Get selected nodes
      selected_nodes = []
      $selected.each () ->
        node = $(this).data("object")
        # get the x/y node min and max to place the new node at the center
        min_x = Math.min(min_x, node.get("x"))
        max_x = Math.max(max_x, node.get("x"))
        min_y = Math.min(min_y, node.get("y"))
        max_y = Math.max(max_y, node.get("y"))
        
        # add the node model to the selected array
        selected_nodes.push(node)
      
      # compute the center node position
      dx = (min_x + max_x) / 2
      dy = (min_y + max_y) / 2
      
      # Create a new GroupDefinition from the selected nodes and connections
      group_def = new ThreeNodes.GroupDefinition
        fromSelectedNodes: selected_nodes
      
      # Save the connection going out or in the group of nodes
      # the connections have one extenal node linked to one selected node
      external_connections = []
      for node in selected_nodes
        # check each node fields
        for field in node.rack.models
          # loop each connections since we can have multiple out connections
          for connection in field.connections
            indx1 = selected_nodes.indexOf(connection.from_field.node)
            indx2 = selected_nodes.indexOf(connection.to_field.node)
            # if "from" OR "out" is external add it
            if indx1 == -1 || indx2 == -1
              # don't add it twice
              already_exists = external_connections.indexOf(connection)
              if already_exists == -1
                external_connections.push(connection)
                
      # remove the nodes
      for node in selected_nodes
        node.remove()
      
      # Create a ThreeNodes.nodes.Group
      grp = @create_node
        type: "Group"
        definition: group_def
        x: dx
        y: dy
      
      # Recreate the external connections
      
      
    removeConnection: (c) ->
      @connections.remove(c)
    
    getNodeByNid: (nid) =>
      for node in @models
        if node.get("nid").toString() == nid
          return node
      return false
    
    showNodesAnimation: () =>
      @invoke "showNodeAnimation"
      @
    
    startSound: (time) =>
      @each (node) ->
        if node.playSound instanceof Function
          node.playSound(time)
      @
    
    stopSound: () =>
      @each (node) ->
        if node.stopSound instanceof Function
          node.stopSound()
      @
    
    removeAll: () ->
      $("#tab-attribute").html("")
      models = @models.concat()
      _.invoke models, "remove"
      @reset([])
      true
    
    removeAllConnections: () ->
      @connections.removeAll()
      