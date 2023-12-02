use starknet::{ContractAddress};
use starknet::ClassHash;

#[starknet::interface]
trait IERC20<TContractState> {
    fn transfer(self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
    fn transferFrom(self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;
}
//0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7 eth token

#[starknet::interface]
trait ICHICK<TContractState> {
    fn free_mint(ref self: TContractState, to: ContractAddress);
}

#[starknet::interface]
trait IEGG<TContractState> {
    fn free_mint(ref self: TContractState, to: ContractAddress, id: u256, amount: u256);
}

#[starknet::interface]
trait INAME<TContractState> {
    fn get_ns(self: @TContractState, _address: ContractAddress) -> felt252;
}

#[derive(Copy, Drop, Serde)]
struct MintInfo{
    chick_mint_num: u256,
    egg_mint_num: u256,
    chick_mint_total: u256,
    egg_mint_total: u256,
    my_mint_chick: bool,
    start_mint: bool,
    my_mint_egg: u256,
    max_egg_mint_each: u256,
}

#[starknet::interface]
trait IFree_Mint<TContractState> {
    fn free_mint_chick(ref self: TContractState);
    fn free_mint_egg(ref self: TContractState, amount: u256, version: u8);
    fn set_eth20_address(ref self: TContractState, _ethaddress: ContractAddress);
    fn set_egg_mint_price(ref self: TContractState, _price: u256);
    fn set_nft_address(ref self: TContractState, _chick_nft_address: ContractAddress, _egg_nft_address: ContractAddress);
    fn set_name_address(ref self: TContractState, _name_address: ContractAddress);
    fn set_max_egg_mint_each(ref self: TContractState, amount: u256);
    fn set_chick_egg_total(ref self: TContractState, _chick_total: u256, _egg_total: u256);
    fn set_start_mint(ref self: TContractState, _start: bool);
    fn get_mint_info(self: @TContractState, contract_address: ContractAddress) ->MintInfo;
    fn get_owner(self: @TContractState) -> ContractAddress;
    fn claim(ref self: TContractState, _amount: u256);
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
}


#[starknet::contract]
mod Free_Mint {
    use core::zeroable::Zeroable;
    use super::IERC20DispatcherTrait;
    use super::IERC20Dispatcher;
    use super::ICHICKDispatcherTrait;
    use super::ICHICKDispatcher;
    use super::IEGGDispatcherTrait;
    use super::IEGGDispatcher;
    use super::INAMEDispatcherTrait;
    use super::INAMEDispatcher;
    use super::IFree_Mint;
    use super::MintInfo;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use starknet::get_block_timestamp;
    use starknet::ClassHash;
    use traits::Into;
    use traits::TryInto;
    use option::OptionTrait;

    #[storage]
    struct Storage {
       owner: ContractAddress,
       name_address: ContractAddress,
       chick_nft_address: ContractAddress,
       egg_nft_address: ContractAddress,
       my_chick_mint: LegacyMap<ContractAddress, bool>,
       my_egg_mint: LegacyMap<ContractAddress, u256>,
       max_egg_mint_each: u256,
       egg_mint_price: u256,
       chick_mint_num: u256,
       egg_mint_num: u256,
       chick_mint_total: u256,
       egg_mint_total: u256,
       eth20_address: ContractAddress,
       start_mint: bool,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Upgraded: Upgraded
    }

    #[derive(Drop, starknet::Event)]
    struct Upgraded {
        class_hash: ClassHash
    }

    #[constructor]
    fn constructor(ref self: ContractState, _owner: ContractAddress){
        self.owner.write(_owner);
        self.egg_mint_price.write(1000000000000000);//0.001
        self.chick_mint_total.write(10000);
        self.egg_mint_total.write(100000);
        self.chick_mint_num.write(0);
        self.egg_mint_num.write(0);
        self.start_mint.write(false);
    }

    #[external(v0)]
    impl Free_Mint of IFree_Mint<ContractState> {

        fn free_mint_chick(ref self: ContractState){
            assert(self.start_mint.read(), 'not start');
            let caller: ContractAddress = get_caller_address();
            assert(!self.my_chick_mint.read(caller), 'already mint');
            assert(self.chick_mint_num.read() < self.chick_mint_total.read(), 'total amount reached');
            let name = INAMEDispatcher { contract_address: self.name_address.read() }.get_ns(caller);
            assert(name.is_non_zero(), 'Ineligible Address');
            self.my_chick_mint.write(caller, true);
            ICHICKDispatcher { contract_address: self.chick_nft_address.read() }.free_mint(caller);
            self.chick_mint_num.write(self.chick_mint_num.read() + 1);
        }

        fn free_mint_egg(ref self: ContractState, amount: u256, version: u8){
            assert(self.start_mint.read(), 'not start');
            let caller: ContractAddress = get_caller_address();
            assert(amount > 0, 'amount not allow');
            assert(self.my_egg_mint.read(caller) + amount <= self.max_egg_mint_each.read(), 'amount not allow');
            assert(self.egg_mint_num.read() + amount <= self.egg_mint_total.read(), 'total amount reached');
            //todo pay ETH
            if(version == 0){
                IERC20Dispatcher { contract_address: self.eth20_address.read() }.transferFrom(caller, get_contract_address(), (self.egg_mint_price.read() * amount));
            }else{
                IERC20Dispatcher { contract_address: self.eth20_address.read() }.transfer_from(caller, get_contract_address(), (self.egg_mint_price.read() * amount));
            }
            self.my_egg_mint.write(caller, self.my_egg_mint.read(caller) + amount);
            self.egg_mint_num.write(self.egg_mint_num.read() + amount);
            IEGGDispatcher { contract_address: self.egg_nft_address.read() }.free_mint(caller, 1, amount);
        }

        fn set_eth20_address(ref self: ContractState, _ethaddress: ContractAddress){
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'not owner');
            self.eth20_address.write(_ethaddress);
        }

        fn set_egg_mint_price(ref self: ContractState, _price: u256){
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'not owner');
            assert(_price > 0, 'price not allow');
            self.egg_mint_price.write(_price);
        }

        fn set_nft_address(ref self: ContractState, _chick_nft_address: ContractAddress, _egg_nft_address: ContractAddress){
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'not owner');
            self.chick_nft_address.write(_chick_nft_address);
            self.egg_nft_address.write(_egg_nft_address);
        }

        fn set_name_address(ref self: ContractState, _name_address: ContractAddress){
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'not owner');
            self.name_address.write(_name_address);
        }

        fn set_max_egg_mint_each(ref self: ContractState, amount: u256){
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'not owner');
            assert(amount > 0, 'amount not allow');
            self.max_egg_mint_each.write(amount);
        }

        fn set_chick_egg_total(ref self: ContractState, _chick_total: u256, _egg_total: u256){
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'not owner');
            assert(_chick_total > 0, 'chick_total not allow');
            assert(_egg_total > 0, 'egg_total not allow');
            self.chick_mint_total.write(_chick_total);
            self.egg_mint_total.write(_egg_total);
        }

        fn set_start_mint(ref self: ContractState, _start: bool){
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'not owner');
            self.start_mint.write(_start);
        }

        fn get_mint_info(self: @ContractState, contract_address: ContractAddress) ->MintInfo{
            let infos = MintInfo{   chick_mint_num: self.chick_mint_num.read(),
                                    egg_mint_num: self.egg_mint_num.read(),
                                    chick_mint_total: self.chick_mint_total.read(),
                                    egg_mint_total: self.egg_mint_total.read(),
                                    my_mint_chick: self.my_chick_mint.read(contract_address),
                                    start_mint: self.start_mint.read(),
                                    my_mint_egg: self.my_egg_mint.read(contract_address),
                                    max_egg_mint_each: self.max_egg_mint_each.read(),};
            infos
        }

        fn get_owner(self: @ContractState) -> ContractAddress{
            self.owner.read()
        }

        fn claim(ref self: ContractState, _amount: u256){
            let caller: ContractAddress = get_caller_address();
            assert(self.owner.read() == caller, 'not owner');
            IERC20Dispatcher { contract_address: self.eth20_address.read() }.transfer(caller, _amount);
        }

        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            let caller: ContractAddress = get_caller_address();
            assert(self.owner.read() == caller, 'not owner');
            assert(!new_class_hash.is_zero(), 'Class hash cannot be zero');
            starknet::replace_class_syscall(new_class_hash).unwrap();
            self.emit(Upgraded { class_hash: new_class_hash });
        }

    }

    // #[external(v0)]
    // fn reset_for_test(ref self: ContractState){
    //     let caller: ContractAddress = get_caller_address();
    //     assert(self.owner.read() == caller, 'not owner');
    //     self.my_chick_mint.write(caller, false);
    //     self.my_egg_mint.write(caller, 0);
    // }
    
}