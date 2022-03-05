const GameNFTs = artifacts.require("GameNFTs");

module.exports = function (deployer) {
  deployer.deploy(GameNFTs,"Game","GMN");
};
