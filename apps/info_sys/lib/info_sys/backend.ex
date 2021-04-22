defmodule InfoSys.Backend do
  # A behaviour is like a contract
  # Every module that uses this needs to implement those callbacks

  @callback name() :: String.t()
  @callback compute(query :: String.t(), opts :: Keyword.t()) :: [%InfoSys.Result{}]
end
