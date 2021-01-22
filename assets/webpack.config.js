
let path = require("path");

let bundleTarget = process.env.target === "node" ? 'node': 'web';

console.log("bundle mode:", bundleTarget);

module.exports = {
  entry: "./main.mjs",
  target: bundleTarget,
  mode: "development",
  devtool: "hidden-source-map",
  output: {
    path: path.resolve(__dirname, "./"),
    filename: "bundle.js",
  },
};
