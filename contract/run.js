const Web3 = require('web3');
const solc = require('solc');
const path = require('path');
const fs = require('fs-extra');

let private = '0x2a5769a6056a67fd4206d48097ca280d4e39fa2b127398b7cce90e9c5ebedc2d';

let web3 = new Web3('http://192.168.2.20:8545');