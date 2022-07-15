## 市场
owner: `0x90a1fe91e0dfc467a64acca393b94ea062d456ff`
privateKey: `0x2a5769a6056a67fd4206d48097ca280d4e39fa2b127398b7cce90e9c5ebedc2d`

### 宙斯天神协议
合约地址: ``

合约ABI: `/contract/god_abi.json`

### 预言机
合约地址: `0xD9a051ff087Cc93110C42af9Ae883ec64967aB44`

预言机ABI

```json
[{
	"constant": true,
	"inputs": [{
		// 代币合约地址
		"internalType": "contract AToken",
		"name": "_aToken",
		"type": "address"
	}],
	"name": "getUnderlyingPrice", // call, 底层资产币价
	"outputs": [{
		"internalType": "uint256",
		"name": "",
		"type": "uint256"
	}],
	"payable": false,
	"stateMutability": "view",
	"type": "function"
}]
```

### 基础资产、利率模型、代币

代币ABI: `/contract/contract_abi.json`

|底层资产地址|底层资产小数位|底层资产币名|利率模型合约地址|利率备注|代币地址|代币名|代币小数位|
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
|`0x9BB5F8F177Fd4C4795dd11C3233c5b93d11Ccce3`|`8`|`DAI`|`0xd95A6E357a59dbb34E8d8e02E3b1db744e6616d1`|加给利率`8.9%`, 基础利率`5%`, 保留利率`2.5`, 兑换率`0.02`, 抵押率`75%`|`0x963c3bAD6ddDd9cA6759d27B481A1dd32A72B481`|`DAI-AEGIS`|`8`|
|`-`|`18`|`ETH`|`0xec925d34C7760F6a6B8F421f08560Ad105Cd6cEf`|加给利率`10%`, 基础利率`3%`, 兑换率`0.02`, 保留利率`3`, 抵押率`75%`|`0x5392e6386884B4E85A8D2FA49296fFA980DE60CC`|`ETH-AEGIS`|`8`|
|`0xaD0dC09b0667CCdf224b45e67BA1e6f7B696743b`|`8`|`USDC`|`0x9aef1c7e671c0cfBd975cBD77Cf45369A80c62D1`|加给利率`5%`, 基础利率`6%`, 兑换率`0.02`, 保留利率`2.5`, 抵押率`75%`|`0x274FA510afBaCCe770e46C51C364e311bf904115`|`USDC-AEGIS`|`8`|
|`0x2347c7E0f77Dd1a2312Bed0D1343E359f6Ce0b77`|`8`|`0X`|`0xC0077960e178F77E6C8db2e22b943B45a94bBB67`|加给利率`37.69%`, 基础利率`0`, 兑换率`0.02`, 保留利率`10`, 抵押率`60%`|`0x8EbEBb7E72FADB0A0a67cc314be8C187A6065f89`|`0X-AEGIS`|`8`|
|`0x70745C557Fc47F8C01B2623B50Cf240DAdaC76b6`|`8`|`USDT`|`0x9914E0aA649e6Be98e701b4cdcf92126F087b326`|加给利率`12%`, 基础利率`3%`, 兑换率`0.02`, 保留利率`3`, 抵押率`0`|`0x480df6E588158E6d970C268B990f5114b1D58aA5`|`USDT-AEGIS`|`8`|
|`0x5A1bA7a85377Ef3Ca6A3f12A8EEFdfc0CB1B3796`|`8`|`BAT`|`0xAE3B652FfE6221319A81324A60D16Dd9CE65C793`|加给利率`37.69%`, 基础利率`0%`, 兑换率`0.02`, 保留利率`50`, 抵押率`60%`|`0x43ef43e7253Ad26915A4A30a35DE1B322Ab08687`|`BAT-AEGIS`|`8`|
|`0x5D1516866aE529922e5223f7A490949E6A1E0726`|`8`|`WBTC`|`0x7b2Ed6EFB90C0346280bd72BEA28A4bFd68FB38d`|加给利率`6%`, 基础利率`5%`, 兑换率`0.02`, 保留利率`3`, 抵押率`40%`|`0x69C8908b1A2c28BFB3F3caCf0E539290760552f5`|`WBTC-AEGIS`|`8`|

### 宙斯协议

合约地址: `0xC2D02a3Fa5a8dBaA15F200cfCa9997cfF39BC5Eb`

合约ABI: `/contract/comptroller_abi.json`

## 详解ABI

### 账户相关

#### 启用宙斯协议

代币协议

```json
[{
	"constant": false,
	"inputs": [{
		// 代币合约地址
		"internalType": "address",
		"name": "_spender",
		"type": "address"
	}, {
		// -1 表示无限
		"internalType": "uint256",
		"name": "_amount",
		"type": "uint256"
	}],
	"name": "approve", // send, 启用宙斯协议
	"outputs": [{
		"internalType": "bool",
		"name": "",
		"type": "bool"
	}],
	"payable": false,
	"stateMutability": "nonpayable",
	"type": "function"
}, {
	"constant": true,
	"inputs": [{
		// 用户钱包地址
		"internalType": "address",
		"name": "_owner",
		"type": "address"
	}, {
		// 代币合约地址
		"internalType": "address",
		"name": "_spender",
		"type": "address"
	}],
	"name": "allowance", // call, 是否启用(授权交易的余币数，为0时需要再次授权)
	"outputs": [{
		"internalType": "uint256",
		"name": "",
		"type": "uint256"
	}],
	"payable": false,
	"stateMutability": "view",
	"type": "function"
}]
```

#### supply

代币协议

```json
{
	"constant": false,
	"inputs": [{
		// supply的币个数
		"internalType": "uint256",
		"name": "_mintAmount",
		"type": "uint256"
	}],
	"name": "mint", // send, supply
	"outputs": [{
		"internalType": "uint256",
		"name": "",
		"type": "uint256"
	}],
	"payable": false,
	"stateMutability": "nonpayable",
	"type": "function"
}
```

#### collateral

宙斯协议 `0xC2D02a3Fa5a8dBaA15F200cfCa9997cfF39BC5Eb`

```json
[{
	"constant": false,
	"inputs": [{
		"internalType": "address[]",
		"name": "_aTokens",
		"type": "address[]"
	}],
	"name": "enterMarkets", // send, 开启抵押
	"outputs": [{
		"internalType": "uint256[]",
		"name": "",
		"type": "uint256[]"
	}],
	"payable": false,
	"stateMutability": "nonpayable",
	"type": "function"
}, {
	"constant": false,
	"inputs": [{
		"internalType": "address",
		"name": "_aTokenAddress",
		"type": "address"
	}],
	"name": "exitMarket", // send, 取消抵押
	"outputs": [{
		"internalType": "uint256",
		"name": "",
		"type": "uint256"
	}],
	"payable": false,
	"stateMutability": "nonpayable",
	"type": "function"
}, {
	"constant": true,
	"inputs": [{
		"internalType": "address",
		"name": "_account",
		"type": "address"
	}, {
		"internalType": "contract AToken",
		"name": "_aToken",
		"type": "address"
	}],
	"name": "checkMembership", // call, 查询抵押状态
	"outputs": [{
		"internalType": "bool",
		"name": "",
		"type": "bool"
	}],
	"payable": false,
	"stateMutability": "view",
	"type": "function"
}]
```

#### borrow

代币协议

```json
{
	"constant": false,
	"inputs": [{
		// borrow的金额
		"internalType": "uint256",
		"name": "_borrowerAmount",
		"type": "uint256"
	}],
	"name": "borrow", // send, borrow
	"outputs": [{
		"internalType": "uint256",
		"name": "",
		"type": "uint256"
	}],
	"payable": false,
	"stateMutability": "nonpayable",
	"type": "function"
}
```

#### repay

代币协议

```json
[{
	"constant": false,
	"inputs": [{
		"internalType": "uint256",
		"name": "_repayAmount",
		"type": "uint256"
	}],
	"name": "repayBorrow", // send, 自己还款
	"outputs": [{
		"internalType": "uint256",
		"name": "",
		"type": "uint256"
	}],
	"payable": false,
	"stateMutability": "nonpayable",
	"type": "function"
}, {
	"constant": false,
	"inputs": [{
		"internalType": "address",
		"name": "_borrower",
		"type": "address"
	}, {
		"internalType": "uint256",
		"name": "_repayAmount",
		"type": "uint256"
	}],
	"name": "repayBorrowBehalf", // send, 他人待还(帮他人偿还)
	"outputs": [{
		"internalType": "uint256",
		"name": "",
		"type": "uint256"
	}],
	"payable": false,
	"stateMutability": "nonpayable",
	"type": "function"
}]
```

#### supply balance

代币协议

```json
[{
  "constant": true,
  "inputs": [{
	// 账户钱包地址
    "internalType": "address",
    "name": "_owner",
    "type": "address"
  }],
  "name": "balanceOf", // call, 账户代币余币(乘以兑换率得到包含本息的底层资产余币)
  "outputs": [{
    "internalType": "uint256",
    "name": "",
    "type": "uint256"
  }],
  "payable": false,
  "stateMutability": "view",
  "type": "function"
}, {
  "constant": false,
  "inputs": [{
	// 账户钱包地址
    "internalType": "address",
    "name": "_owner",
    "type": "address"
  }],
  "name": "balanceOfUnderlying", // call, 放贷的底层资产余币
  "outputs": [{
    "internalType": "uint256",
    "name": "",
    "type": "uint256"
  }],
  "payable": false,
  "stateMutability": "nonpayable",
  "type": "function"
}]
```

#### borrow balance

代币协议

```json
[{
	"constant": false,
	"inputs": [{
		// 账户钱包地址
		"internalType": "address",
		"name": "_account",
		"type": "address"
	}],
	"name": "borrowBalanceCurrent", // call
	"outputs": [{
		"internalType": "uint256",
		"name": "",
		"type": "uint256"
	}],
	"payable": false,
	"stateMutability": "nonpayable",
	"type": "function"
}, {
	"constant": true,
	"inputs": [{
		// 账户钱包地址
		"internalType": "address",
		"name": "_address",
		"type": "address"
	}],
	"name": "getAccountSnapshot", // call 账户详情
	"outputs": [{
		"internalType": "uint256",
		"name": "",
		"type": "uint256"
	}, {
		// 代币个数
		"internalType": "uint256",
		"name": "",
		"type": "uint256"
	}, {
		// borrow balance
		"internalType": "uint256",
		"name": "",
		"type": "uint256"
	}, {
		// exchangeRate
		"internalType": "uint256",
		"name": "",
		"type": "uint256"
	}],
	"payable": false,
	"stateMutability": "view",
	"type": "function"
}]
```

#### withdraw

代币协议

```json
[{
	"constant": false,
	"inputs": [{
		"internalType": "uint256",
		"name": "_redeemTokens",
		"type": "uint256"
	}],
	"name": "redeem", // send, 提取代币，换取基础资产
	"outputs": [{
		"internalType": "uint256",
		"name": "",
		"type": "uint256"
	}],
	"payable": false,
	"stateMutability": "nonpayable",
	"type": "function"
}, {
	"constant": false,
	"inputs": [{
		"internalType": "uint256",
		"name": "_redeemAmount",
		"type": "uint256"
	}],
	"name": "redeemUnderlying", // send, 提取代币，换取指定数量的基础资产
	"outputs": [{
		"internalType": "uint256",
		"name": "",
		"type": "uint256"
	}],
	"payable": false,
	"stateMutability": "nonpayable",
	"type": "function"
}]
```

#### 存入市场但是未被借走的底层资产

代币协议

```json
{
	"constant": true,
	"inputs": [],
	"name": "getCash", // call
	"outputs": [{
		"internalType": "uint256",
		"name": "",
		"type": "uint256"
	}],
	"payable": false,
	"stateMutability": "view",
	"type": "function"
}
```

### 市场展示相关

#### exchangeRate

代币协议

```json
{
	"constant": true,
	"inputs": [],
	"name": "exchangeRateStored", // call, 兑换率
	"outputs": [{
		"internalType": "uint256",
		"name": "",
		"type": "uint256"
	}],
	"payable": false,
	"stateMutability": "view",
	"type": "function"
}
```

#### supply apy

代币协议

```json
{
	"constant": true,
	"inputs": [],
	"name": "supplyRatePerBlock", // call, 当前区块的 supplyRate
	"outputs": [{
		"internalType": "uint256",
		"name": "",
		"type": "uint256"
	}],
	"payable": false,
	"stateMutability": "view",
	"type": "function"
}
```

#### borrow apy

代币协议

```json
{
	"constant": true,
	"inputs": [],
	"name": "borrowRatePerBlock", // call, 当前区块的 borrowRate
	"outputs": [{
		"internalType": "uint256",
		"name": "",
		"type": "uint256"
	}],
	"payable": false,
	"stateMutability": "view",
	"type": "function"
}
```

#### 清算

宙斯协议: `0xC2D02a3Fa5a8dBaA15F200cfCa9997cfF39BC5Eb`

```json
[{
	"constant": true,
	"inputs": [],
	"name": "closeFactorMantissa", // call, 清算利率(1e18)
	"outputs": [{
		"internalType": "uint256",
		"name": "",
		"type": "uint256"
	}],
	"payable": false,
	"stateMutability": "view",
	"type": "function"
}, {
	"constant": true,
	"inputs": [],
	"name": "liquidationIncentiveMantissa", // call, 清算费率(平台收，1e18)
	"outputs": [{
		"internalType": "uint256",
		"name": "",
		"type": "uint256"
	}],
	"payable": false,
	"stateMutability": "view",
	"type": "function"
}]
```

### 以太坊代币操作
小数位1e18

ABI: `contract_eth_abi.json`

#### supply

```json
{
	"constant": false,
	"inputs": [],
	"name": "mint", // send, 数量为value
	"outputs": [],
	"payable": true,
	"stateMutability": "payable",
	"type": "function"
}
```

#### withdraw

```json
[{
	"constant": false,
	"inputs": [{
		"internalType": "uint256",
		"name": "_redeemTokens",
		"type": "uint256"
	}],
	"name": "redeem",
	"outputs": [{
		"internalType": "uint256",
		"name": "",
		"type": "uint256"
	}],
	"payable": false,
	"stateMutability": "nonpayable",
	"type": "function"
}, {
	"constant": false,
	"inputs": [{
		"internalType": "uint256",
		"name": "_redeemAmount",
		"type": "uint256"
	}],
	"name": "redeemUnderlying",
	"outputs": [{
		"internalType": "uint256",
		"name": "",
		"type": "uint256"
	}],
	"payable": false,
	"stateMutability": "nonpayable",
	"type": "function"
}]
```

#### borrow

```json
{
	"constant": false,
	"inputs": [{
		"internalType": "uint256",
		"name": "_borrowAmount",
		"type": "uint256"
	}],
	"name": "borrow",
	"outputs": [{
		"internalType": "uint256",
		"name": "",
		"type": "uint256"
	}],
	"payable": false,
	"stateMutability": "nonpayable",
	"type": "function"
}
```

#### repayBorrow

```json
[{
	"constant": false,
	"inputs": [],
	"name": "repayBorrow",
	"outputs": [],
	"payable": true,
	"stateMutability": "payable",
	"type": "function"
}, {
	"constant": false,
	"inputs": [{
		"internalType": "address",
		"name": "_borrower",
		"type": "address"
	}],
	"name": "repayBorrowBehalf",
	"outputs": [],
	"payable": true,
	"stateMutability": "payable",
	"type": "function"
}]
```

## 测试

价格预言机: 0xcE52250C210425C78cd54034eB8E7BBDE7492284

宙斯协议: 0x7E192d9586241E6A7d6039537cC2E483a414C0D6


|底层资产地址|底层资产小数位|底层资产币名|利率模型合约地址|利率备注|代币地址|代币名|代币小数位|
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
|`0x80cBAc73eAeF6d90c12Ad79c936153856e892231`|`8`|`DAI`|`0xfFb597665f55bb04Af79F752575B4B1560d37d4C`|加给利率`8.9%`, 基础利率`5%`, 保留利率`2.5`, 兑换率`0.02`, 抵押率`75%`|`0x91a8E1C7BCAe81fCeb2944EFF95f8047FDDcaEB9`|`DAI-AEGIS`|`8`|
|`-`|`18`|`ETH`|`0x738C900c4Ba3C51C0Da58F6Cb0a3532171dF805e`|加给利率`10%`, 基础利率`3%`, 兑换率`0.02`, 保留利率`3`, 抵押率`75%`|`0x8C70fA64481E8D483006B045A50695C067EbbfC2`|`ETH-AEGIS`|`8`|
|`0xb75e3fD80e149341262E9ce0E7b695C08aFdFC2d`|`8`|`USDC`|`0x72Df7216CFf24F1F052dB4b0bD8Bf2b4bA9af9f1`|加给利率`5%`, 基础利率`6%`, 兑换率`0.02`, 保留利率`2.5`, 抵押率`75%`|`0x1C736AdC5c7062127dF601E2EEcDc1540FCC9B50`|`USDC-AEGIS`|`8`|
|`0x0bD839B4A1bDd804ECD434683916bb89b84583b0`|`8`|`0X`|`0x78a28e3082dD59fCDfC21e824194d30100db5aD4`|加给利率`37.69%`, 基础利率`0`, 兑换率`0.02`, 保留利率`10`, 抵押率`60%`|`0x21daAd080d3A129a30F62223CB1A37CF3Ee21F34`|`0X-AEGIS`|`8`|
|`0x276729dB7273E990f2B33883dA18c03630C20C6F`|`8`|`USDT`|`0x009b47990A7Bc8F0Cc7137371e9916fb6709943b`|加给利率`12%`, 基础利率`3%`, 兑换率`0.02`, 保留利率`3`, 抵押率`0`|`0xcbE456d5E333Bb350Ff29a926ac5fd153d3B97Fb`|`USDT-AEGIS`|`8`|
|`0xEe12deEd3616B59EC92DdE7F4f6d1aE7d3dB244f`|`8`|`BAT`|`0x5be0b4f54e9c9B55290AAE0Dd207f8D2424874a1`|加给利率`37.69%`, 基础利率`0%`, 兑换率`0.02`, 保留利率`50`, 抵押率`60%`|`0x15aa673AdfCD5D1d584f4A644a770b97C55D5e4F`|`BAT-AEGIS`|`8`|
|`0xd05bc1748B6e032D6FfADA2E731CA3558B62BfF6`|`8`|`WBTC`|`0xe54070F4d92E311Fd7fA6aF08CC9D2d3C77F2f11`|加给利率`6%`, 基础利率`5%`, 兑换率`0.02`, 保留利率`3`, 抵押率`40%`|`0x569Bc19fAfb470F3588849750f681Adbc2Fc733A`|`WBTC-AEGIS`|`8`|