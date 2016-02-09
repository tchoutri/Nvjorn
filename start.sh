export MIX_ENV=prod 
echo $MIX_ENV

mix deps.get
mix compile
iex --name "nvjorn@$(hostname -f)" -S mix
unset MIX_ENV
echo $MIX_ENV
