const Web3 = require('web3');
const solc = require('solc');
const path = require('path');
const fs = require('fs-extra');

let web3 = new Web3('http://192.168.2.20:8545');
let private = '0x2a5769a6056a67fd4206d48097ca280d4e39fa2b127398b7cce90e9c5ebedc2d';

let contractPath = 'contract/base';
let contractName = 'AErc20';
let contract_fileName = contractName + '.sol';

function findImports(path_) {
  try {
    let file_path = path.resolve(__dirname, contractPath, path_);
    if (fs.existsSync(file_path)) {
      return {
        contents: fs.readFileSync(file_path, 'utf-8')
      };
    } else {
      return { error: 'File not found' };
    }
  } catch(err) {
    console.error(err)
    return { error: 'File not found' };
  }
}

function compile() {
  let bytecodes = [];
  let compiled = JSON.parse(solc.compile(JSON.stringify({
    language: 'Solidity',
    settings: {
      optimizer: {
        enabled: true
      },
      outputSelection: {
        '*': {
          '*': [ 'evm.bytecode.object', 'abi' ]
        }
      }
    },
    sources: {
      contract_fileName: {
        content: fs.readFileSync(path.resolve(__dirname, contractPath, contract_fileName), 'utf8')
      }
    }
  }), { import: findImports }));
  // console.log(compiled);
  for (let contract in compiled.contracts) {
    for (let xx in compiled.contracts[contract])
    bytecodes.push([xx, compiled.contracts[contract][xx].evm.bytecode.object, JSON.stringify(compiled.contracts[contract][xx].abi)]);
  }
  return bytecodes;
}

let xx = compile();
// console.log(xx);

for (let item in xx){
  if(xx[item][0] === contractName){
    console.log(xx[item]);
    // let contract_abi = JSON.parse(xx[item][2])[0]; // json
    // let types = []
    // for (let type in contract_abi.inputs) {
    //   types.push(contract_abi.inputs[type].type);
    // }

    // let account = web3.eth.accounts.privateKeyToAccount(private);
    // account.signTransaction({
    //   value: '0x0',
    //   gas: '0x7a1200',
    //   gasPrice: '0xdf8475800',
    //   data: xx[item][1] // 字节码
    //   // data: xx[item][1] + web3.eth.abi.encodeParameters(types, [8.9 * 10**8, 5 * 10**8]).slice(2)
    // }).then(signedTx => web3.eth.sendSignedTransaction(signedTx.rawTransaction))
    // .then(receipt => console.log("Transaction receipt: ", receipt))
    // .catch(err => console.error(err));
  }
}

// let contract_abi = JSON.parse(xx[0][1])[0];
// let types = []
// for (let type in contract_abi.inputs) {
//   types.push(contract_abi.inputs[type].internalType);
// }

// let account = web3.eth.accounts.privateKeyToAccount(private);
// account.signTransaction({
//   value: '0x0',
//   gas: '0x7a1200',
//   gasPrice: '0xdf8475800',
//   // data: xx[0][1]
//   data: xx[0][1] + web3.eth.abi.encodeParameters(types, ['', '']).slice(2)
// }).then(signedTx => web3.eth.sendSignedTransaction(signedTx.rawTransaction))
// .then(receipt => console.log("Transaction receipt: ", receipt))
// .catch(err => console.error(err));