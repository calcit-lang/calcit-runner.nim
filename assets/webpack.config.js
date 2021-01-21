
const path = require("path");

module.exports = {
  entry: "./main.mjs",
  target: 'node',
  mode: "development",
  devtool: "hidden-source-map",
  output: {
    path: path.resolve(__dirname, "./"),
    filename: "bundle.js",
  },
};
