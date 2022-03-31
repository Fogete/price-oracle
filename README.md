# Price Oracle

A maintenance-free, decentralized, manipulation-resistant price oracle for use with implementations of [IUniswapV2Pair](https://uniswap.org/docs/v2/smart-contracts/pair/).

# Computing average prices

To compute the average price given two cumulative price observations, take the difference between the cumulative price at the beginning and end of the period, and divide by the elapsed time between them in seconds. This will produce a fixed point unsigned Q112x112 number that represents the price of one asset relative to the other. This number is represented as a uint224 where the upper 112 bits represent the integer amount, and the lower 112 bits represent the fractional amount.

Pairs contain both price0CumulativeLast and price1CumulativeLast, which are ratios of reserves of token1/token0 and token0/token1 respectively. I.e. the price of token0 is expressed in terms of token1/token0, while the price of token1 is expressed in terms of token0/token1.

# Time-weighted average prices (TWAPs) across any time interval.

The TWAP is constructed by reading the cumulative price from an ERC20 token pair at the beginning and at the end of the desired interval. The difference in this cumulative price can then be divided by the length of the interval to create a TWAP for that period.

Uniswap V2 adds the end-of-block price to a single cumulative-price variable in the core contract weighted by the amount of time this price existed. This variable represents a sum of the Uniswap price for every second in the entire history of the contract.

- For a 10-minute TWAP, sample once every 10 minutes. For a 1-week TWAP, sample once every week.
- For a simple TWAP, the cost of manipulation increases (approx. linear) with liquidity on Uniswap, as well as (approx. linear) with the length of time over which you average.
- The Cost of an attack is relatively simple to estimate. Moving the price 5% on a 1-hour TWAP is approximately equal to the amount lost to arbitrage and fees for moving the price 5% every block for 1 hour.
