-- Inofficial Solana Extension for MoneyMoney
-- Fetches Solana quantity for address via solana mainnet API
-- Fetches Solana price in EUR via cryptocompare API
-- Returns cryptoassets as securities
--
-- Username: Solana Adresses comma seperated
-- Password: Does not matter

-- MIT License

-- Copyright (c) 2021 Johannes Fritsch

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.


WebBanking{
  version = 0.1,
  description = "Include your Solana as cryptoportfolio in MoneyMoney by providing Solana adresses (username, comma seperated)",
  services= { "Solana" }
}

local solAddresses
local coinbaseApiKey
local connection = Connection()
local currency = "EUR" -- fixme: make dynamic if MoneyMoney enables input field

function SupportsBank (protocol, bankCode)
  return protocol == ProtocolWebBanking and bankCode == "Solana"
end

function InitializeSession (protocol, bankCode, username, username2, password, username3)
  solAddresses = username:gsub("%s+", "")
  coinbaseApiKey = password
end

function ListAccounts (knownAccounts)
  local account = {
    name = "Solana",
    accountNumber = "Crypto Asset Solana",
    currency = currency,
    portfolio = true,
    type = "AccountTypePortfolio"
  }

  return {account}
end

function RefreshAccount (account, since)
  local s = {}
  prices = requestSolPrice()

  for address in string.gmatch(solAddresses, '([^,]+)') do
    lamportQuantity = requestLamportQuantityForSolAddress(address)
    lamportQuantityStaked = requestLamportQuantityStakedForSolAddress(address)
    solQuantity = convertLamportsToSol(lamportQuantity)
    solQuantityStaked = convertLamportsToSol(lamportQuantityStaked)

    s[#s+1] = {
      name = address,
      currency = nil,
      market = "cryptocompare",
      quantity = solQuantity,
      price = prices["EUR"],
    }
    s[#s+1] = {
      name = address .. " (Staked)",
      currency = nil,
      market = "cryptocompare",
      quantity = solQuantityStaked,
      price = prices["EUR"],
    }
  end

  return {securities = s}
end

function EndSession ()
end


-- Querry Functions
function requestSolPrice()
  content = connection:request("GET", cryptocompareRequestUrl(), {})
  json = JSON(content)

  return json:dictionary()
end

function requestLamportQuantityForSolAddress(solAddress)
  content = connection:post("https://api.mainnet-beta.solana.com", JSON():set({
    ["jsonrpc"] = "2.0",
    ["id"] = "1",
    ["method"] = "getBalance",
    ["params"] = { solAddress }
  }):json(), "application/json")
  json = JSON(content)

  return json:dictionary()["result"]["value"]
end

function requestLamportQuantityStakedForSolAddress(solAddress)
  content = connection:post("https://api.mainnet-beta.solana.com", JSON():set({
    method = "getProgramAccounts",
    jsonrpc = "2.0",
    params = { "Stake11111111111111111111111111111111111111", {
      encoding = "jsonParsed",
      commitment = "confirmed",
      filters = { {
        memcmp = {
          bytes = "EjhmR3ZwBmE4dtZQbAno3zuEZ1R3RqaTiiY9JsdtUM1A",
          offset = 12
        }
      } }
    } },
    id = "0b3781ff-4d64-4052-815a-2628d0c6e7b7"
  }):json(), "application/json")
  json = JSON(content)

  return json:dictionary()["result"][1]["account"]["data"]["parsed"]["info"]["stake"]["delegation"]["stake"]
end

-- Helper Functions
function convertLamportsToSol(lamports)
  return lamports / 1000000000
end

function cryptocompareRequestUrl()
  return "https://min-api.cryptocompare.com/data/price?fsym=SOL&tsyms=EUR,USD"
end
