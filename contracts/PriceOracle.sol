pragma solidity =0.5.16;

import "./libraries/UQ112x112.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IPriceOracle.sol";

contract TarotPriceOracle is ITarotPriceOracle {
  using UQ112x112 for uint224;

  uint32 public constant MIN_T = 1200;

  struct Pair {
    uint priceCumulativeSlotA;
    uint priceCumulativeSlotB;
    uint32 lastUpdateSlotA;
    uint32 lastUpdateSlotB;
    bool latestIsSlotA;
    bool initialized;
  }
  mapping(address => Pair) public getPair;

  event PriceUpdate(
    address indexed pair,
    uint priceCumulative,
    uint32 blockTimestamp,
    bool latestIsSlotA
  );

  function toUint224(uint input) internal pure returns (uint224) {
    require(input <= uint224(-1), "TarotPriceOracle: UINT224_OVERFLOW");
    return uint224(input);
  }

  function getPriceCumulativeCurrent(address uniswapV2Pair)
    internal
    view
    returns (uint priceCumulative)
  {
    priceCumulative = IUniswapV2Pair(uniswapV2Pair).price0CumulativeLast();
    (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = IUniswapV2Pair(
      uniswapV2Pair
    ).getReserves();
    uint224 priceLatest = UQ112x112.encode(reserve1).uqdiv(reserve0);
    uint32 timeElapsed = getBlockTimestamp() - blockTimestampLast; // Overflow is desired
    // * Never overflows, and + overflow is desired
    priceCumulative += uint(priceLatest) * timeElapsed;
  }

  function initialize(address uniswapV2Pair) external {
    Pair storage pairStorage = getPair[uniswapV2Pair];
    require(!pairStorage.initialized, "TarotPriceOracle: ALREADY_INITIALIZED");

    uint priceCumulativeCurrent = getPriceCumulativeCurrent(uniswapV2Pair);
    uint32 blockTimestamp = getBlockTimestamp();
    pairStorage.priceCumulativeSlotA = priceCumulativeCurrent;
    pairStorage.priceCumulativeSlotB = priceCumulativeCurrent;
    pairStorage.lastUpdateSlotA = blockTimestamp;
    pairStorage.lastUpdateSlotB = blockTimestamp;
    pairStorage.latestIsSlotA = true;
    pairStorage.initialized = true;
    emit PriceUpdate(uniswapV2Pair, priceCumulativeCurrent, blockTimestamp, true);
  }

  function getResult(address uniswapV2Pair) external returns (uint224 price, uint32 T) {
    Pair memory pair = getPair[uniswapV2Pair];
    require(pair.initialized, "TarotPriceOracle: NOT_INITIALIZED");
    Pair storage pairStorage = getPair[uniswapV2Pair];

    uint32 blockTimestamp = getBlockTimestamp();
    uint32 lastUpdateTimestamp = pair.latestIsSlotA
      ? pair.lastUpdateSlotA
      : pair.lastUpdateSlotB;
    uint priceCumulativeCurrent = getPriceCumulativeCurrent(uniswapV2Pair);
    uint priceCumulativeLast;

    if (blockTimestamp - lastUpdateTimestamp >= MIN_T) {
      // Update price
      priceCumulativeLast = pair.latestIsSlotA
        ? pair.priceCumulativeSlotA
        : pair.priceCumulativeSlotB;
      if (pair.latestIsSlotA) {
        pairStorage.priceCumulativeSlotB = priceCumulativeCurrent;
        pairStorage.lastUpdateSlotB = blockTimestamp;
      } else {
        pairStorage.priceCumulativeSlotA = priceCumulativeCurrent;
        pairStorage.lastUpdateSlotA = blockTimestamp;
      }
      pairStorage.latestIsSlotA = !pair.latestIsSlotA;
      emit PriceUpdate(
        uniswapV2Pair,
        priceCumulativeCurrent,
        blockTimestamp,
        !pair.latestIsSlotA
      );
    } else {
      // Don't update; return price using previous priceCumulative
      lastUpdateTimestamp = pair.latestIsSlotA
        ? pair.lastUpdateSlotB
        : pair.lastUpdateSlotA;
      priceCumulativeLast = pair.latestIsSlotA
        ? pair.priceCumulativeSlotB
        : pair.priceCumulativeSlotA;
    }

    T = blockTimestamp - lastUpdateTimestamp; // Overflow is desired
    require(T >= MIN_T, "TarotPriceOracle: NOT_READY"); // Reverts only if the pair has just been initialized
    // Is safe, and - overflow is desired
    price = toUint224((priceCumulativeCurrent - priceCumulativeLast) / T);
  }

  /*** Utilities ***/

  function getBlockTimestamp() public view returns (uint32) {
    return uint32(block.timestamp % 2**32);
  }
}
