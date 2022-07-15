# Aegis Contract

## 业务

**ETH不需要启用宙斯协议, USDT不允许抵押, 不能supply/borrow同币种**

### 启用宙斯协议

`ETH` 不需要启用该协议

即授权智能合约转账户钱包余币，当额度为0时需再次授权(启用宙斯协议)

### 启用抵押/关闭抵押

`USDT` 不允许进行此项操作
  - 启用抵押: 币种的原始资产按照抵押率得到贷款额度
  - 关闭抵押: 币种的原始资产不计入贷款额度

### supply

存入底层资产，按照当时的兑换率获得放贷凭证(代币)

### withdraw

销毁代币，按照当时的兑换率以获取底层资产

### borrow

不能borrow已supply的币种

supply的资产，按照抵押率得到borrow limit

### repay

授权销毁底层资产

## 小数位计算相关

市场相关数据
  - **Exchange Rate**: 兑换率, 1e18
    * TotalSupply=0, Exchange Rate=0
    * Exchange Rate = (TotalCash + TotalBorrows - TotalReserves) / TotalSupply
  - **Collateral Rate**: 抵押率, 1e18
  - **BaseRate**: 基础利率, 1e18
  - **ReserveRate**: 保留利率, 1e18
  - **MultiplierRate**: 加给利率, 1e18
  - **Liquidation Rate**: 清算率, 1e18
  - **Liquidation Penalty**: 清算费率(平台收入), 1e18
    * 得到的数值需要减去100%再渲染到界面上展示
  - **Utilization Rate**: 使用率, 1e18
    * Borrows=0, Utilization Rate=0
    * Utilization Rate = Borrows / (Cash + Borrows - Reserves)
  - **Borrow APY**: 一年固定2102400个区块. 当前区块的borrow利率, 1e18
    * 阈值前: Borrow APY = UtilizationRate * MultiplierRate + BaseRate
    * 阈值后: Borrow APY = (UtilizationRate - kink) * achieveMultiplierRate + (kink * MultiplierRate + BaseRate)
  - **Supply APY**: 一年固定2102400个区块. 当前区块的supply利率, 1e18
    * Supply APY = UtilizationRate * (BorrowAPY*(1 - ReserveRate))
  - **Underlying Price**: 底层资产的币价, 1e8

账户操作时传入的参数 **必须是整数**
  - **supply**: 底层资产的小数位
  - **withdraw**: 
  - **borrow**: 底层资产的小数位
  - **repay**: 

## 部署和测试

### 部署

|代币|底层资产币种|抵押率|初始兑换率|基础利率|加给利率|保留利率|使用率阈值|阈值后加给利率|
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
|`DAI-AEGIS`|`DAI`|`75%`|`2%`|`0`|`5%`|`5%`|`80%`|`105%`|
|`ETH-AEGIS`|`ETH`|`75%`|`2%`|`0`|`12.75%`|`10%`|`80%`|`105%`|
|`USDC-AEGIS`|`USDC`|`75%`|`2%`|`0`|`10.73%`|`10%`|`80%`|`105%`|
|`0X-AEGIS`|`0X`|`60%`|`2%`|`0%`|`12.75%`|`10%`|`80%`|`105%`|
|`USDT-AEGIS`|`USDT`|`0`|`2%`|`0`|`5%`|`10%`|`80%`|`105%`|
|`BAT-AEGIS`|`BAT`|`60%`|`2%`|`0`|`35.67%`|`5%`|`80%`|`105%`|
|`WBTC-AEGIS`|`WBTC`|`40%`|`2%`|`0`|`35.67%`|`10%`|`80%`|`105%`|

#### 底层资产 Aegis.sol

底层资产以太坊正式网不需要部署

#### 预言机 PriceOracle.sol

部署后须初始化币价
  - postUnderlyingPrice: 代币地址对应的底层资产价格
    * U系列都是1:1，不需要初始化

#### 宙斯协议 AegisComptroller.sol

部署后得到合约地址, 可供ERC-20`initialize`、和AETH的`constructor`使用

须初始化以下方法
  - _setCollateralFactor: 抵押率, 值小于0.9e18
    1. AToken _aToken: 代币合约地址
    2. uint _newCollateralFactorMantissa: 抵押率
  - _setCloseFactor: 清算率, 0.05e18 ~ 0.9e18. 现默认为44.35%
  - _setLiquidationIncentive: 清算费率(平台收入), 1e18 ~ 1.5e18. 现默认为110%
  - _setMaxAssets: 用户允许进入的最大市场(允许抵押的币种最大个数)
    1. uint maxAssets: 最大个数
  - _setPriceOracle: 设置价格预言机合约地址
    1. PriceOracle _newOracle: 价格预言机合约地址
  - _supportMarket: 设置市场币种(即marketList), 有几种代币就需要执行几次本方法
    1. AToken _aToken: 代币合约地址

#### 兼容阈值的利率模型 AchieveInterestRateModel.sol

构造函数部署合约
  - constructor
    1. uint _baseRatePerYear: 基础利率, 1e18
    2. uint _multiplierPerYear: 加给利率, 1e18
    3. uint _achieveMultiplierPerYear: 阈值后的加给利率, 1e18
    4. uint _kink: 阈值(当前默认为80%), 1e18
    5. address _owner: owner

#### ERC-20代币 AErc20.sol

部署后得到合约地址, 可供宙斯协议`_supportMarket`方法使用

须执行以下方法初始化
  - initialize
    1. address _underlying: 底层资产的合约地址
    2. AegisComptrollerInterface _comptroller: 宙斯协议合约地址
    3. InterestRateModel _interestRateModel: 利率模型的合约地址
    4. uint _initialExchangeRateMantissa: 初始兑换率, 1e18
    5. string memory _name: 代币name
    6. string memory _symbol: 代币symbol
    7. uint8 _decimals: 代币decimals
    8. address payable _admin: admin
  - _setReserveFactor: 保留利率, 值小于1e18

#### ETH代币 AEther.sol

构造函数部署合约
  - constructor
    1. AegisComptrollerInterface _comptroller: 宙斯协议合约地址
    2. InterestRateModel _interestRateModel: 利率模型合约地址
    3. uint _initialExchangeRateMantissa: 初始兑换率
    4. string memory _name: 代币name
    5. string memory _symbol: 代币symbol
    6. uint8 _decimals: 代币decimals
    7. address payable _admin: admin
  - _setReserveFactor: 保留利率, 值小于1e18