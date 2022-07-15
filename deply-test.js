const Web3 = require('web3');
const solc = require('solc');
const path = require('path');
const fs = require('fs-extra');
const EventEmitter = require('events');

class Compiler {
  constructor(basePath) {
    this.basePath = basePath;
    let warp = (basePath) => {
      return (path_) => {
        try {
          let file_path = path.resolve(__dirname, basePath, path_);
          if (fs.existsSync(file_path)) {
            return {
              contents: fs.readFileSync(file_path, 'utf-8')
            };
          } else {
            return {
              error: 'File not found'
            };
          }
        } catch (err) {
          console.error(err)
          return {
            error: 'File not found'
          };
        }
      }
    };
    this.findImports = warp(basePath);
  }

  compile(contractName, contractFileName) {
    let bytecodes = null;
    let compiled = JSON.parse(solc.compile(JSON.stringify({
      language: 'Solidity',
      settings: {
        optimizer: {
          enabled: true
        },
        outputSelection: {
          '*': {
            '*': ['evm.bytecode.object', 'abi']
          }
        }
      },
      sources: {
        contractFileName: {
          content: fs.readFileSync(path.resolve(__dirname, this.basePath, contractFileName), 'utf8')
        }
      }
    }), {
      import: this.findImports
    }));
    for (let contract in compiled.contracts) {
      for (let xx in compiled.contracts[contract]) {
        if (xx != contractName)
          continue;
        bytecodes = [xx, compiled.contracts[contract][xx].evm.bytecode.object, compiled.contracts[contract][xx].abi];
      }
    }
    return bytecodes;
  }
}

const baseCompiler = new Compiler('contract/base');
const testCompiler = new Compiler('contract/test');
const [STEP_PREPARE_UNDERLYING, STEP_DEPLOY, STEP_PREPARE_ORACLE_AND_RATE_MODEL, STEP_PREPARE_AEGIS_PROTOCOL, STEP_PREPARE_ERC20_AND_ETH, STEP_INIT_CONTRACT] = ['step1', 'step', 'step2', 'step3', 'step4', 'step5'];
const web3 = new Web3('http://testnet.eth.aegis.finance');
const private = '0x9e9f131ba5c7802da9ba59b63070ce791a3b999333492b0b97147999b9c7ff63';
const account = web3.eth.accounts.privateKeyToAccount(private);
const event = new EventEmitter();
var info = {};
const coins = ['DAI', 'USDT', 'USDC', '0X', 'BAT', 'WBTC'];
var public_info = JSON.parse('[{"asset":"DAI","name":"Dai","constract_address":"0x9BB5F8F177Fd4C4795dd11C3233c5b93d11Ccce3","decimal":8,"APY_address":"0xaD5A0339aa53e906AF0C37AdA776EE0CdfC3cdc6","AGS_address":"0xDa2748dce4C3EC6Cc92690C1497b98CB986F8848","token_decimal":8,"unit":"DAI"},{"asset":"USDC","name":"USD Coin","constract_address":"0x70745C557Fc47F8C01B2623B50Cf240DAdaC76b6","decimal":8,"APY_address":"0xb1c2880e21500A8Ad8d1a7fDB4eFf0299f7D5ECa","AGS_address":"0x6fa26D37338b86633C8261f4bCd416D63439C5bA","token_decimal":8,"unit":"USDC"},{"asset":"ETH","name":"Ether","constract_address":"","decimal":18,"APY_address":"0x40A9ef5B11Df386956b1671418aFe9F851cD63b2","AGS_address":"0xb75e3fD80e149341262E9ce0E7b695C08aFdFC2d","token_decimal":8,"unit":"ETH"},{"asset":"0x","name":"0x","constract_address":"0xaD0dC09b0667CCdf224b45e67BA1e6f7B696743b","decimal":8,"APY_address":"0x00e41844873c3f3Aa9017b2967BAE24AcA2BBee4","AGS_address":"0xd9Eed83c64364282E3b21E3b7F583739Cd797cd2","token_decimal":8,"unit":"0x"},{"asset":"USDT","name":"Tether","constract_address":"0x2347c7E0f77Dd1a2312Bed0D1343E359f6Ce0b77","decimal":8,"APY_address":"0xc4D12c0a84B63EecB357808886F2f09896854562","AGS_address":"0x332A68e5b28335274b1C8936D664F48A9ddB269B","token_decimal":8,"unit":"USDT"},{"asset":"BAT","name":"Basic Attention Token","constract_address":"0x5A1bA7a85377Ef3Ca6A3f12A8EEFdfc0CB1B3796","decimal":8,"APY_address":"0xd636132b1d3333d5e96F0D6064607c30E4488494","AGS_address":"0xc4b58597381563B5108c574E945502c8ed95dcCc","token_decimal":8,"unit":"BAT"},{"asset":"WBTC","name":"Wrapped BTC","constract_address":"0x5D1516866aE529922e5223f7A490949E6A1E0726","decimal":8,"APY_address":"0xa06B22DE35199927e395F378888CCB4797d19Bae","AGS_address":"0xdbbff06BD118312f290d2Aab0205f96f2c9a86ae","token_decimal":8,"unit":"WBTC"}]')

function getComplement(num) {
  num = Math.abs(num);
  let bin = ''
  while (num != 0) {
    bin += parseInt(num % 2).toString();
    num = parseInt(num / 2);
  }
  bin = `${'0'.repeat(256 - bin.length)}${bin.split('').reverse().join('')}`;

  let rverse = '';
  for (let char of bin) {
    rverse += ['1', '0'][parseInt(char)];
  }
  bin = rverse;
  let carry = 0;
  for (let i = bin.length - 1; i >= 0; --i) {
    let current = parseInt(bin[i]);
    if (i == bin.length - 1) {
      current += 1;
    }
    if (current + carry > 1) {
      bin = bin.substr(0, i) + '0' + bin.substr(i + 1);
      carry = 1;
    } else {
      bin = bin.substr(0, i) + (current + carry).toString() + bin.substr(i + 1);
      carry = 0;
    }
  }
  let result = BigInt(0);
  for (let i = 0; i < bin.length; ++i) {
    let current = BigInt(bin[i]);
    result += (current * BigInt(2) ** BigInt(bin.length - i - 1));
  }
  return result.toString();
}

function deploy(name, to, data, abi, cb) {
  account.signTransaction({
      to: to,
      value: '0x0',
      gas: '0x7a1200',
      gasPrice: '0xdf8475800',
      data: data
    }).then(signedTx => web3.eth.sendSignedTransaction(signedTx.rawTransaction))
    .then(receipt => {
      cb(name, abi, receipt);
    })
    .catch(err => console.error(err));
}

function getConstructParamsTypes(abi) {
  let contract_abi = abi[0]; // get construct function abi
  let types = [] // to save contruct params type
  for (let type in contract_abi.inputs) {
    types.push(contract_abi.inputs[type].type);
  }
  return types;
}

event.on(STEP_INIT_CONTRACT, () => {
  let queue = [];

  const rates = {
    // c, e, r
    'AErc20-DAI': [75, 2, 5],
    AEther: [75, 2, 10],
    'AErc20-USDC': [75, 2, 10],
    'AErc20-USDT': [null, 2, 10],
    'AErc20-0X': [60, 2, 10],
    'AErc20-BAT': [60, 2, 5],
    'AErc20-WBTC': [40, 2, 10]
  };

  let contract = new web3.eth.Contract(info['PriceOracle'].abi, info['PriceOracle'].address);
  for (const [k, v] of Object.entries(rates)) {
    queue.push([`PriceOracle::postUnderlyingPrice(${k})`, contract.options.address, contract.methods.postUnderlyingPrice(info[k].address, web3.utils.toBN(parseInt(1 * 10 ** 8))).encodeABI(), '']);
  }

  contract = new web3.eth.Contract(info['AegisComptroller'].abi, info['AegisComptroller'].address);

  queue.push(['AegisComptroller::_setPriceOracle', contract.options.address, contract.methods._setPriceOracle(info['PriceOracle'].address).encodeABI(), '']);
  for (let i in coins) {
    queue.push([`AegisComptroller::_supportMarket(${coins[i]})`, contract.options.address, contract.methods._supportMarket(info[`AErc20-${coins[i]}`].address).encodeABI(), '']);
  }
  queue.push(['AegisComptroller::_supportMarket(ETH)', contract.options.address, contract.methods._supportMarket(info['AEther'].address).encodeABI(), '']);

  for (const [k, v] of Object.entries(rates)) {
    if (v[0] == null)
      continue;
    queue.push([`AegisComptroller::_setCollateralFactor(${k})`, contract.options.address, contract.methods._setCollateralFactor(info[k].address, web3.utils.toBN(parseInt(v[0] * 10 ** 16))).encodeABI(), '']);
  }
  queue.push(['AegisComptroller::_setCloseFactor', contract.options.address, contract.methods._setCloseFactor(web3.utils.toBN(parseInt(44.35 * 10 ** 16))).encodeABI(), '']);
  queue.push(['AegisComptroller::_setLiquidationIncentive', contract.options.address, contract.methods._setLiquidationIncentive(web3.utils.toBN(parseInt(110 * 10 ** 16))).encodeABI(), '']);
  queue.push(['AegisComptroller::_setMaxAssets', contract.options.address, contract.methods._setMaxAssets(8).encodeABI(), '']);

  for (let i in coins) {
    contract = new web3.eth.Contract(info[`AErc20-${coins[i]}`].abi, info[`AErc20-${coins[i]}`].address);
    let data = contract.methods.initialize(info[coins[i]].address, info['AegisComptroller'].address, info[`AchieveInterestRateModel-${coins[i]}-AEGIS`].address, web3.utils.toBN(parseInt(rates[`AErc20-${coins[i]}`][1] * 10 ** 16)), coins[i], coins[i], 8, account.address).encodeABI();
    queue.push([`AErc20-${coins[i]}::initialize`, contract.options.address, data, ''])
    queue.push([`AErc20-${coins[i]}::_setReserveFactor`, contract.options.address, contract.methods._setReserveFactor(web3.utils.toBN(parseInt(rates[`AErc20-${coins[i]}`][2] * 10 ** 16))).encodeABI(), ''])
  }

  contract = new web3.eth.Contract(info[`AEther`].abi, info[`AEther`].address);
  queue.push([`AEther::_setReserveFactor`, contract.options.address, contract.methods._setReserveFactor(web3.utils.toBN(parseInt(rates[`AEther`][2] * 10 ** 16))).encodeABI(), '']);

  event.emit(STEP_DEPLOY, queue, '');
});

event.on(STEP_PREPARE_ERC20_AND_ETH, () => {
  let queue = [];
  let name = 'AEther';
  let abi = baseCompiler.compile(name, `${name}.sol`);
  let params = [info['AegisComptroller']['address'], info['AchieveInterestRateModel-ETH-AEGIS']['address'], web3.utils.toBN(parseInt(2 * 10 ** 16)), 'ETH', 'ETH', 8, account.address];
  queue.push([`${name}`, null, abi[1] + web3.eth.abi.encodeParameters(getConstructParamsTypes(abi[2]), params).slice(2), abi[2]]);

  name = 'AErc20';
  abi = baseCompiler.compile(name, `${name}.sol`);
  for (let i in coins) {
    queue.push([`${name}-${coins[i]}`, null, abi[1], abi[2]]);
  }

  event.emit(STEP_DEPLOY, queue, STEP_INIT_CONTRACT);
});

event.on(STEP_PREPARE_AEGIS_PROTOCOL, () => {
  let queue = [];
  let name = 'AegisComptroller';
  let abi = baseCompiler.compile(name, `${name}.sol`);
  queue.push([name, null, abi[1], abi[2]]);
  event.emit(STEP_DEPLOY, queue, STEP_PREPARE_ERC20_AND_ETH);
});

event.on(STEP_PREPARE_ORACLE_AND_RATE_MODEL, () => {
  let queue = [];
  let name = 'PriceOracle';
  let abi = baseCompiler.compile(name, `${name}.sol`);
  queue.push([name, null, abi[1] + web3.eth.abi.encodeParameters(getConstructParamsTypes(abi[2]), [account.address]).slice(2), abi[2]]);

  // name = 'AegisRateModel';
  // abi = baseCompiler.compile(name, `${name}.sol`);
  // for (let i in rates) {
  //   let params = [web3.utils.toBN(parseInt(rates[i][1] * 10 ** 16)), web3.utils.toBN(parseInt(rates[i][2] * 10 ** 16))];
  //   queue.push([`${name}-${rates[i][0]}`, null, abi[1] + web3.eth.abi.encodeParameters(getConstructParamsTypes(abi[2]), params).slice(2), abi[2]]);
  // }

  name = 'AchieveInterestRateModel';
  let rates = [
    ['DAI-AEGIS', 0, 5, 105, 80],
    ['ETH-AEGIS', 0, 12.75, 105, 80],
    ['USDC-AEGIS', 0, 10.73, 105, 80],
    ['0X-AEGIS', 0, 12.75, 105, 80],
    ['USDT-AEGIS', 0, 5, 105, 80],
    ['BAT-AEGIS', 0, 35.67, 105, 80],
    ['WBTC-AEGIS', 0, 35.67, 105, 80]
  ];
  abi = baseCompiler.compile(name, `${name}.sol`);
  for (let i in rates) {
    if (rates[i][3] == null)
      continue;
    let params = [web3.utils.toBN(parseInt(rates[i][1] * 10 ** 16)), web3.utils.toBN(parseInt(rates[i][2] * 10 ** 16)), web3.utils.toBN(parseInt(rates[i][3] * 10 ** 16)), web3.utils.toBN(parseInt(rates[i][4] * 10 ** 16)), account.address];
    queue.push([`${name}-${rates[i][0]}`, null, abi[1] + web3.eth.abi.encodeParameters(getConstructParamsTypes(abi[2]), params).slice(2), abi[2]]);
  }

  event.emit(STEP_DEPLOY, queue, STEP_PREPARE_AEGIS_PROTOCOL);
});

event.on(STEP_DEPLOY, (queue, next) => {
  if (queue.length < 1) {
    if (next == '') {
      for (const [k, v] of Object.entries(public_info)) {
        public_info[k].APY_address = info[`AchieveInterestRateModel-${v.asset.toUpperCase()}-AEGIS`].address;
        if (v.asset.toUpperCase() == 'ETH') {
          public_info[k].AGS_address = info['AEther'].address;
        } else {
          public_info[k].constract_address = info[v.asset.toUpperCase()].address;
          public_info[k].AGS_address = info[`AErc20-${v.asset.toUpperCase()}`].address;
        }
      }
      console.log(JSON.stringify(public_info));
    }
    event.emit(next);
    return;
  }
  let data = queue[0];
  deploy(...data, (name, abi, receipt) => {
    if (receipt.status) {
      let contractAddress = receipt.contractAddress;
      if (typeof contractAddress != "undefined" && contractAddress != null && contractAddress != "") {
        console.log(name, receipt.contractAddress);
        info[name] = {
          address: receipt.contractAddress,
          abi: abi
        }
      } else {
        console.log(name, receipt.status);
      }
      queue.shift();
    }
    event.emit(STEP_DEPLOY, queue, next);
  })
});

event.on(STEP_PREPARE_UNDERLYING, () => {
  let name = 'Aegis';
  let abi = testCompiler.compile(name, `${name}.sol`);
  let queue = [];
  for (let i in coins) {
    queue.push([coins[i], null, abi[1] + web3.eth.abi.encodeParameters(getConstructParamsTypes(abi[2]), [800000000, coins[i], coins[i]]).slice(2), abi[2]]);
  }
  event.emit(STEP_DEPLOY, queue, STEP_PREPARE_ORACLE_AND_RATE_MODEL);
});

event.emit(STEP_PREPARE_UNDERLYING);