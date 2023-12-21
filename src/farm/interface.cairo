use starknet::{ContractAddress};
use starknet::ClassHash;

#[starknet::interface]
trait IERC20<TContractState> {
    fn transfer(self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    fn transferFrom(self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
}

#[starknet::interface]
trait IRANDOM<TContractState> {
    fn get_random(ref self: TContractState) -> u64;
}

#[starknet::interface]
trait ICHICK<TContractState> {
    fn mint(ref self: TContractState, to: ContractAddress);
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
    fn burn(ref self: TContractState, token_id: u256);
}

#[starknet::interface]
trait IEGG<TContractState> {
    fn mint(ref self: TContractState, to: ContractAddress, id: u256, amount: u256);
    fn balance_of(self: @TContractState, account: ContractAddress, id: u256) -> u256;
    fn burn(ref self: TContractState, from: ContractAddress, id: u256, amount: u256);
}

#[starknet::interface]
trait IFarm<TContractState> {
    fn create_farm(ref self: TContractState, name: felt252, _invite: ContractAddress);
    fn be_node(ref self: TContractState, version: u8, _node_name: felt252);
    fn be_node_whitelist(ref self: TContractState, _node_name: felt252);
    fn update_node_name(ref self: TContractState, _node_name: felt252);
    fn update_farm_name(ref self: TContractState, name: felt252);
    fn add_nft_to_farm(ref self: TContractState, nft_id: u256);
    fn add_egg_to_farm(ref self: TContractState, amount: u32);
    fn egg_to_nft(ref self: TContractState, amount: u32);
    fn buy_food(ref self: TContractState, food_amount: u32);
    fn feed_chick(ref self: TContractState);
    fn choose_egg_hatch(ref self: TContractState, _choose: u8);
    fn reap_egg(ref self: TContractState, version: u8);
    fn reap_chick(ref self: TContractState, version: u8);
    fn eat_worm(ref self: TContractState);
    fn steal_egg_from_other_gardon(ref self: TContractState, from_addr: ContractAddress);
    fn claim(ref self: TContractState, _amount: u256);
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
}

#[starknet::interface]
trait IFarmSet<TContractState> {
    fn set_nft_address(ref self: TContractState, _chick_nft_address: ContractAddress, _egg_nft_address: ContractAddress);
    fn set_ngt_eth20_address(ref self: TContractState, _ngt_address: ContractAddress, _eth20_address: ContractAddress);
    fn set_random_address(ref self: TContractState, _random_address: ContractAddress);
    fn set_burn_address(ref self: TContractState, _burn_address: ContractAddress);
    fn set_food_node_price(ref self: TContractState, _food_price: u256, _node_price: u256);
    fn set_hatch_need_egg(ref self: TContractState, _hatch_need_egg: u32);
    fn set_grow_hatch_time(ref self: TContractState, _grow_time: u64, _hatch_time: u64);
    fn set_each_egg_time(ref self: TContractState, _each_egg_time: u64);
    fn set_steal_start_time(ref self: TContractState, _steal_start_time: u64);
    fn set_worm_sustain_time(ref self: TContractState, _worm_sustain_time: u64);
    fn set_base_egg_chick(ref self: TContractState, _base_egg: u32, _base_chick: u32);
    fn set_stolen_cooling_egg(ref self: TContractState, _can_stolen_egg: u32, _steal_cooling_time: u64);
    fn set_random_chick(ref self: TContractState, _random_chick: bool);
    fn set_whitelist(ref self: TContractState, _white_address: ContractAddress, _trueornot: bool);
    fn set_percentage(ref self: TContractState, _invite_percentage: u128, _node_percentage: u128);
    fn set_reap_fee(ref self: TContractState, _reap_egg_fee: u256, _reap_chick_fee: u256);
}

#[starknet::interface]
trait IFarmInfo<TContractState> {
    fn check_worm_time(self: @TContractState, call_addr: ContractAddress) -> (bool, u32);
    fn get_hatch_chick_num(self: @TContractState, addr: ContractAddress) -> u32;
    fn get_node_name(self: @TContractState, contract_address: ContractAddress) -> felt252;
    fn get_my_node_name(self: @TContractState, invite_address: ContractAddress) -> (ContractAddress, felt252);
    fn get_owner(self: @TContractState) -> ContractAddress;
    fn get_chick_info(self: @TContractState, contract_address: ContractAddress) -> ChickInfo;
    fn get_num_info(self: @TContractState) ->NumInfo;
}

#[derive(Copy, Drop, Serde)]
struct ChickInfo{
    my_farm_level: u256,
    my_chick_id: u256,
    chick_status: u32,
    eggs: u32,
    chick_food: u32,
    my_stolen: u32,
    my_worms: u32,
    my_eat_worms: u32,
    update_time: u64,
    block_chain_time: u64,
    grow_time: u64,
    hatch_time: u64,
    each_egg_time: u64,
    farm_name: felt252,
    food_price: u256,
    node_price: u256,
    reap_egg_fee: u256,
    reap_chick_fee: u256,
    base_egg: u32,
}

#[derive(Copy, Drop, Serde)]
struct NumInfo{
    burn_chick_num: u256, 
    brun_egg_num: u256, 
    chick_gardon_num: u256, 
    hatching_chick_num: u256, 
    laying_chick_num: u256, 
    egg_gardon_num: u256, 
}