################################################################################
# A scene graph is a simple way to organize the rendering of 2D images.
# It organises the elements by a Z value where elements with a lower value gets
# rendered later and therefore in front of other elements with a higher Z value.
#
# This scene graph doesn't take objects of any particular kind but rather
# procedures that takes a renderer, and a pair of coordinates (of the scene
# graph origin). It can also take any object that has such a procedure related
# to it. Note that the scene graph is one such object, so nesting scene graphs
# is possible.
#
# Add calls to the scene graph also returns an object which can be used to
# delete an element or change it's Z value. These objects don't reference their
# scene graph so care must be taken to always update and delete from the right
# scene graph.
################################################################################


import sdl2

type
  RenderProc* = proc(renderer: RendererPtr, x, y: cint)

  Renderable = concept x
    render(RendererPtr, x, cint, cint)

  RenderNode* = ref object
    render: RenderProc
    z: int
    last, next: RenderNode

  SceneGraph* = ref object
    renderables: RenderNode

proc insert(sceneGraph: SceneGraph, startNode: RenderNode, renderNode: var RenderNode, right: bool = true) =
  if sceneGraph.renderables == nil:
    sceneGraph.renderables = renderNode
    return# renderNode

  var node = startNode
  while true:
    if node.z < renderNode.z:
      renderNode.last = node.last
      renderNode.next = node
      node.last = renderNode
      if renderNode.last != nil:
        renderNode.last.next = renderNode
      else:
        sceneGraph.renderables = renderNode
      return# renderNode
    if right:
      if node.next == nil:
        node.next = renderNode
        renderNode.last = node
        return# renderNode
      node = node.next
    else:
      if node.last == nil:
        node.last = renderNode
        renderNode.next = node
        return
      node = node.last

proc add*[T:Renderable](sceneGraph: SceneGraph, z: int, renderable: T): RenderNode=
  result = RenderNode(
    render: proc(renderer: RendererPtr, x, y: cint) =
      renderer.render(renderable,x,y),
    z: z
  )
  sceneGraph.insert(sceneGraph.renderables, result)

proc add*(sceneGraph: SceneGraph, z: int, renderProc: RenderProc): RenderNode =
  result = RenderNode(
    render: renderProc,
    z: z
  )
  sceneGraph.insert(sceneGraph.renderables, result)

proc delete*(sceneGraph: SceneGraph, renderNode: RenderNode) =
  if sceneGraph.renderables == renderNode:
    sceneGraph.renderables = renderNode.next
    if sceneGraph.renderables != nil:
      sceneGraph.renderables.last = nil
  else:
    var node = sceneGraph.renderables.next
    while node != nil:
      if node == renderNode:
        node.last.next = node.next
        if node.next != nil:
          node.next.last = node.last
        break
      node = node.next

proc changeZ*(sceneGraph: SceneGraph, renderNode: var RenderNode, newZ: int) =
  if renderNode.z > newZ:
    renderNode.z = newZ
    sceneGraph.delete(renderNode)
    var nextNode = renderNode.next
    renderNode.next = nil
    renderNode.last = nil
    sceneGraph.insert(nextNode, renderNode, true)
  if renderNode.z < newZ:
    renderNode.z = newZ
    sceneGraph.delete(renderNode)
    var lastNode = renderNode.last
    if lastNode == nil:
      lastNode = sceneGraph.renderables
    renderNode.next = nil
    renderNode.last = nil
    sceneGraph.insert(lastNode, renderNode, false)

proc render*(renderer: RendererPtr, sceneGraph: SceneGraph, x,y: cint) =
  var node = sceneGraph.renderables
  while node != nil:
    node.render(renderer,x,y)
    node = node.next

proc newSceneGraph*(): SceneGraph =
  new result
