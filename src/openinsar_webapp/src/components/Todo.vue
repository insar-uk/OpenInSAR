<template>
  <div ref="chart"></div>
</template>

<script lang="ts">
import * as d3 from "d3";

interface NodeInterface {
  name: string;
  parent: Node | null;
  children: Node[];
}

class Node implements NodeInterface {
  name: string;
  parent: Node | null;
  children: Node[];

  constructor(name: string, parent: Node | null = null, children: Node[] = []) {
    this.name = name;
    this.parent = parent;
    this.children = children;
  }

  addChild(name: string): Node {
    const node = new Node(name, this);
    this.children.push(node);
    return this;
  }

  findChild(name: string): Node | undefined {
    return this.children.find((child) => child.name === name);
  }
}

const rootNode = new Node("Root");

export default {
  name: "D3Component",
  mounted() {
    this.drawChart();
  },
  methods: {
    drawChart() {
      const data = rootNode
        .addChild("A")
        .addChild("B")
        .addChild("C");

      data.findChild("B")?.addChild("BB_0");
      data.findChild("B")?.addChild("BB_1");
      data.findChild("C")?.addChild("CC");
      data.findChild("B")?.findChild("BB_1")?.addChild("BBB");
      // add a node to the tree
      console.log(data)

      // SETTINGSs
      const width = 1024;
      const fontSize = 22;
      const fontColor = "#000000";
      const backgroundColor = "#aaccff";
      const outlineColor = "#ffffff";
      const lineColor = "#000000";
      const dotSize = fontSize/3;
      const dotColorBranch = "#0066aa";
      const dotColorLeaf = "#0077aa";

      // Compute the tree height; this approach will allow the height of the
      // SVG to scale according to the breadth (width) of the tree layout.
      const root = d3.hierarchy(data);
      const dx = fontSize*1.5;
      const dy = width / (root.height + 1);

      // Create a tree layout.
      const tree = d3.tree().nodeSize([dx, dy]);

      // Sort the tree and apply the layout.
      root.sort((a, b) => d3.ascending(a.data.name, b.data.name));
      tree(root);

      // Compute the extent of the tree. Note that x and y are swapped here
      // because in the tree layout, x is the breadth, but when displayed, the
      // tree extends right rather than down.
      let x0 = Infinity;
      let x1 = -x0;
      root.each((d) => {
        if (d.x > x1) x1 = d.x;
        if (d.x < x0) x0 = d.x;
      });

      // Compute the adjusted height of the tree.
      const height = x1 - x0 + dx * 2;

      const svg = d3
        .create("svg")
        .attr("width", width)
        .attr("height", height)
        .attr("viewBox", [-dy / 3, x0 - dx, width, height])
        .attr("style", "max-width: 100%; height: auto; font: " + fontSize + "px sans-serif;");

      const link = svg
        .append("g")
        .attr("fill", "none")
        .attr("stroke", lineColor)
        .attr("stroke-opacity", 0.4)
        .attr("stroke-width", 1.5)
        .selectAll()
        .data(root.links())
        .join("path")
        .attr(
          "d",
          d3
            .linkHorizontal()
            .x((d) => d.y)
            .y((d) => d.x)
        );

      const node = svg
        .append("g")
        .attr("stroke-linejoin", "round")
        .attr("stroke-width", 3)
        .selectAll()
        .data(root.descendants())
        .join("g")
        .attr("transform", (d) => `translate(${d.y},${d.x})`);

      node
        .append("circle")
        .attr("fill", (d) => (d.children ? dotColorBranch : dotColorLeaf))
        .attr("r", dotSize);

      node
        .append("text")
        .attr("fill", fontColor)
        .attr("dy", "0.31em")
        .attr("x", (d) => (d.children ? -6 : 6))
        .attr("text-anchor", (d) => (d.children ? "end" : "start"))
        .text((d) => d.data.name)
        .clone(true)
        .lower()
        .attr("stroke", outlineColor);

      // Add the svg to the page
        d3.select(this.$refs.chart).node().append(svg.node());
        // Set colour of container
        d3.select(this.$refs.chart).node().style.backgroundColor = backgroundColor;

    }}
};
</script>