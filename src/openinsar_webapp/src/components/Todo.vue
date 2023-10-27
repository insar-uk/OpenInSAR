<template>
  <div>User {{ $route.params.id }}</div>
  <div ref="chart"></div>
</template>

<script lang="ts">
import * as d3 from 'd3'

interface NodeInterface {
  name: string
  parent: MyNode | null
  children: MyNode[]
}

class MyNode implements NodeInterface {
  name: string
  parent: MyNode | null
  children: MyNode[]

  constructor(name: string, parent: MyNode | null = null, children: MyNode[] = []) {
    this.name = name
    this.parent = parent
    this.children = children
  }

  addChild(name: string): MyNode {
    const node = new MyNode(name, this)
    this.children.push(node)
    return this
  }

  findChild(name: string): MyNode | undefined {
    return this.children.find((child) => child.name === name)
  }
}

const rootNode = new MyNode('Root')

export default {
  name: 'D3Component',
  mounted() {
    this.drawChart()
  },
  methods: {
    drawChart() {
      const data = rootNode.addChild('A').addChild('B').addChild('C')

      data.findChild('B')?.addChild('BB_0')
      data.findChild('B')?.addChild('BB_1')
      data.findChild('C')?.addChild('CC')
      data.findChild('B')?.findChild('BB_1')?.addChild('BBB')
      // add a node to the tree
      console.log(data)

      // SETTINGSs
      const width = 1024
      const fontSize = 22
      const fontColor = '#000000'
      const backgroundColor = '#ffffff'
      const outlineColor = '#ffffff'
      const lineColor = '#000000'
      const dotSize = fontSize / 3
      const dotColorBranch = '#0066aa'
      const dotColorLeaf = '#0077aa'

      // Compute the tree height; this approach will allow the height of the
      // SVG to scale according to the breadth (width) of the tree layout.
      const root: d3.HierarchyNode<MyNode> = d3.hierarchy(data)
      const dx = fontSize * 1.5
      const dy = width / (root.height + 1)

      // Create a tree layout.
      const tree = d3.tree().nodeSize([dx, dy])

      // Sort the tree and apply the layout.
      root.sort((a, b) => d3.ascending((a.data as MyNode).name, (b.data as MyNode).name))
      tree(root as d3.HierarchyNode<unknown>)

      // Compute the extent of the tree. Note that x and y are swapped here
      // because in the tree layout, x is the breadth, but when displayed, the
      // tree extends right rather than down.
      let x0 = Infinity
      let x1 = -x0
      root.each((d: any) => {
        if (d.x > x1) x1 = d.x
        if (d.x < x0) x0 = d.x
      })

      // Compute the adjusted height of the tree.
      const height = x1 - x0 + dx * 2

      const svg = d3
        .create('svg')
        .attr('width', width)
        .attr('height', height)
        .attr('viewBox', [-dy / 3, x0 - dx, width, height])
        .attr('style', 'max-width: 100%; height: auto; font: ' + fontSize + 'px sans-serif;')

      svg
        .append('g')
        .attr('fill', 'none')
        .attr('stroke', lineColor)
        .attr('stroke-opacity', 0.5)
        .attr('stroke-width', 1.5)
        .selectAll()
        .data(root.links())
        .join('path')
        .attr(
          'd',
          d3
            .linkHorizontal()
            .x((d: any) => d.y)
            .y((d: any) => d.x) as any
        )

      const node = svg
        .append('g')
        .attr('stroke-linejoin', 'round')
        .attr('stroke-width', 3)
        .selectAll()
        .data(root.descendants())
        .join('g')
        .attr('transform', (d: any) => `translate(${d.y},${d.x})`)

      node
        .append('circle')
        .attr('fill', (d) => (d.children ? dotColorBranch : dotColorLeaf))
        .attr('r', dotSize)

      node
        .append('text')
        .attr('fill', fontColor)
        .attr('dy', '0.31em')
        .attr('x', (d) => (d.children ? -6 : 6))
        .attr('text-anchor', (d) => (d.children ? 'end' : 'start'))
        .text((d) => d.data.name)
        .clone(true)
        .lower()
        .attr('stroke', outlineColor)

      // Get the chart element
      const chart = this.$refs.chart as HTMLElement
      // Add the svg to the page
      chart.appendChild(svg.node() as Node)
      // Set colour of container
      chart.style.backgroundColor = backgroundColor
    }
  }
}
</script>
