#[starknet::contract]
mod Farm {
    use core::zeroable::Zeroable;
    use zkGarden::farm::interface::IERC20DispatcherTrait;
    use zkGarden::farm::interface::IERC20Dispatcher;
    use zkGarden::farm::interface::IRANDOMDispatcherTrait;
    use zkGarden::farm::interface::IRANDOMDispatcher;
    use zkGarden::farm::interface::ICHICKDispatcherTrait;
    use zkGarden::farm::interface::ICHICKDispatcher;
    use zkGarden::farm::interface::IEGGDispatcherTrait;
    use zkGarden::farm::interface::IEGGDispatcher;
    use zkGarden::farm::interface::ChickInfo;
    use zkGarden::farm::interface::NumInfo;
    use zkGarden::farm::interface;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use starknet::get_block_timestamp;
    use starknet::ClassHash;
    use traits::Into;
    use traits::TryInto;
    use option::OptionTrait;

    const HUNDRED_PERCENT: u128 = 10000;

    #[storage]
    struct Storage {
       my_farm: LegacyMap<ContractAddress, felt252>,
       my_farm_level: LegacyMap<ContractAddress, u256>,
       my_node: LegacyMap<ContractAddress, ContractAddress>,
       node_whitelist: LegacyMap<ContractAddress, bool>,
       my_invite: LegacyMap<ContractAddress, ContractAddress>,
       node_name: LegacyMap<ContractAddress, felt252>,
       my_chick_id: LegacyMap<ContractAddress, u256>,//0 or id
       my_stolen_egg: LegacyMap<ContractAddress, u32>,//stolen egg
       my_steal_time: LegacyMap<ContractAddress, u64>,//the last time of my stealing egg
       my_worm: LegacyMap<ContractAddress, u32>,//total worm in my gardon
       my_eat_worm: LegacyMap<ContractAddress, u32>,//my eat
       my_worm_time: LegacyMap<ContractAddress, u64>,//time after layer egg
       my_chick_status: LegacyMap<ContractAddress, u32>,//0 init, 1, add nft, 2 feed, 3 lay egg, 4 hatch
       my_eggs: LegacyMap<ContractAddress, u32>, //0 init
       my_chick_food: LegacyMap<ContractAddress, u32>, //0 init
       my_chick_update_time: LegacyMap<ContractAddress, u64>,
       my_random_chick: LegacyMap<ContractAddress, u32>, //0 init
       owner: ContractAddress,
       worm_sustain_time: u64,//sustain time such as 1 hour
       steal_start_time: u64,//diff time before can steal after lay egg done
       each_egg_time: u64,//each egg lay time
       hatch_time: u64,
       hatch_need_egg: u32,
       grow_time: u64,
       base_egg: u32,//lay egg base amount
       base_chick: u32,//hatch chicks base amount
       can_stolen_egg: u32,//each level can be stolen amount
       steal_cooling_time: u64,
       random_chick: bool,//is random effect
       chick_nft_address: ContractAddress,
       egg_nft_address: ContractAddress,
       ngt_address: ContractAddress,
       eth20_address: ContractAddress,
       random_address: ContractAddress,
       burn_address: ContractAddress,
       food_price: u256,
       node_price: u256,
       reap_egg_fee: u256,
       reap_chick_fee: u256,
       burn_chick_num: u256, //burn chick total 
       brun_egg_num: u256, //burn egg total
       chick_gardon_num: u256, //chick total in garden
       hatching_chick_num: u256, //hatching chicken total in garden
       laying_chick_num: u256, //lay egg chicken total in garden
       egg_gardon_num: u256, //egg nft total in garden
       invite_percentage: u128,
       node_percentage: u128,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Upgraded: Upgraded,
        CreateFarm: CreateFarm,
        CreateInvite: CreateInvite,
        InviteEarn: InviteEarn,
        NodeEarn: NodeEarn,
        BeNode: BeNode,
        UpdateFarmName: UpdateFarmName,
        UpdateNodeName: UpdateNodeName,
        UpdateFarmLevel: UpdateFarmLevel,
        StealEgg: StealEgg
    }

    #[derive(Drop, starknet::Event)]
    struct Upgraded {
        class_hash: ClassHash
    }

    #[derive(Drop, starknet::Event)]
    struct CreateFarm {
        #[key]
        owner: ContractAddress,
        #[key]
        node: ContractAddress,
        name: felt252,
        time: u64
    }

    #[derive(Drop, starknet::Event)]
    struct CreateInvite {
        #[key]
        invited: ContractAddress,
        #[key]
        invitor: ContractAddress,
        time: u64
    }

    #[derive(Drop, starknet::Event)]
    struct InviteEarn {
        #[key]
        earnaddr: ContractAddress,
        #[key]
        fromaddr: ContractAddress,
        amount: u128,
        time: u64
    }

    #[derive(Drop, starknet::Event)]
    struct NodeEarn {
        #[key]
        earnaddr: ContractAddress,
        #[key]
        fromaddr: ContractAddress,
        amount: u128,
        time: u64
    }

    #[derive(Drop, starknet::Event)]
    struct BeNode {
        #[key]
        owner: ContractAddress,
        #[key]
        node: ContractAddress,
        node_name: felt252,
        time: u64
    }

    #[derive(Drop, starknet::Event)]
    struct UpdateFarmName {
        #[key]
        owner: ContractAddress,
        name: felt252,
        time: u64
    }

    #[derive(Drop, starknet::Event)]
    struct UpdateNodeName {
        #[key]
        node: ContractAddress,
        name: felt252,
        time: u64
    }

    #[derive(Drop, starknet::Event)]
    struct UpdateFarmLevel {
        #[key]
        owner: ContractAddress,
        level: u256,
        time: u64
    }

    #[derive(Drop, starknet::Event)]
    struct StealEgg {
        #[key]
        steal: ContractAddress,
        #[key]
        stolen: ContractAddress,
        time: u64
    }

    #[constructor]
    fn constructor(ref self: ContractState, _owner: ContractAddress){
        self.owner.write(_owner);
        self.grow_time.write(3*24*3600);//3*24*3600
        self.hatch_need_egg.write(10);//10 eggs need
        self.hatch_time.write(10*24*3600);//30*24*3600
        self.each_egg_time.write(1*24*3600);//8*24*3600
        self.base_egg.write(16);//egg num
        self.base_chick.write(3);//chick num
        self.steal_start_time.write(10*60);//10*60
        self.can_stolen_egg.write(3);//3
        self.steal_cooling_time.write(30*60);//30 minute
        self.worm_sustain_time.write(1*60*60);//1*60*60
        self.random_chick.write(true);
        self.food_price.write(300000000000000000000); //300 ngt
        self.node_price.write(200000000000000000); //0.2 ETH
        self.reap_egg_fee.write(3000000000000000); //0.003eth
        self.reap_chick_fee.write(5000000000000000); //0.005eth
        self.invite_percentage.write(2000);//2000, 20%
        self.node_percentage.write(4000);//4000, 40%
        self.my_node.write(_owner, _owner);
        let _node_name: felt252 = 'fashion garden';
        self.node_name.write(_owner, _node_name);
        self.emit(BeNode { owner: _owner, node: _owner, node_name: _node_name, time: get_block_timestamp() });
    }

    #[external(v0)]
    impl Farm of interface::IFarm<ContractState> {
        //add community todo
        fn create_farm(ref self: ContractState, name: felt252, _invite: ContractAddress){
            let caller = get_caller_address();
            assert(self.my_farm.read(caller).is_zero(), 'already created');
            let _node = self.my_node.read(_invite);
            assert(self.node_name.read(_node).is_non_zero(), 'invite node unavailable');
            self.my_farm.write(caller, name);
            self.my_farm_level.write(caller, 1);
            self.my_chick_id.write(caller, 0);
            self.my_chick_status.write(caller, 0);
            self.my_eggs.write(caller, 0);
            self.my_chick_food.write(caller, 0);
            self.my_node.write(caller, _node);
            self.my_invite.write(caller, _invite);
            self.emit(CreateInvite { invited: caller, invitor: _invite, time: get_block_timestamp() });
            self.emit(CreateFarm { owner: caller, node: _node, name: name, time: get_block_timestamp()});
        }

        fn be_node(ref self: ContractState, version: u8, _node_name: felt252){
            let caller = get_caller_address();
            assert(self.my_node.read(caller) != caller, 'already node');
            assert(self.my_farm.read(caller).is_non_zero(), 'create farm first');
            let invite_addr = self.my_invite.read(caller);

            let mut _invite_income = 0_u128;
            let _node_price: felt252 = self.node_price.read().try_into().unwrap();
            let _node_price_: u128 = _node_price.try_into().unwrap();
            _invite_income = _node_price_ * self.invite_percentage.read() / HUNDRED_PERCENT;
            let invite_income: u256 = _invite_income.into();

            if(version == 0){
                IERC20Dispatcher { contract_address: self.eth20_address.read() }.transferFrom(caller, get_contract_address(), self.node_price.read() - invite_income);
                IERC20Dispatcher { contract_address: self.eth20_address.read() }.transferFrom(caller, invite_addr, invite_income);
            }else{
                IERC20Dispatcher { contract_address: self.eth20_address.read() }.transfer_from(caller, get_contract_address(), self.node_price.read() - invite_income);
                IERC20Dispatcher { contract_address: self.eth20_address.read() }.transfer_from(caller, invite_addr, invite_income);
            }
            self.my_node.write(caller, caller);
            self.node_name.write(caller, _node_name);
            self.emit(InviteEarn {earnaddr: invite_addr, fromaddr: caller, amount: _invite_income, time: get_block_timestamp()});
            self.emit(BeNode { owner: caller, node: caller, node_name: _node_name, time: get_block_timestamp() });
        }

        fn be_node_whitelist(ref self: ContractState, _node_name: felt252){
            let caller = get_caller_address();
            assert(self.my_node.read(caller) != caller, 'already node');
            assert(self.node_whitelist.read(caller), 'not white list member');
            self.my_node.write(caller, caller);
            self.node_name.write(caller, _node_name);
            self.emit(BeNode { owner: caller, node: caller, node_name: _node_name, time: get_block_timestamp() });
        }

        fn update_node_name(ref self: ContractState, _node_name: felt252){
            let caller = get_caller_address();
            assert(self.my_node.read(caller) == caller, 'not node');
            self.node_name.write(caller, _node_name);
            self.emit(UpdateNodeName { node: caller, name: _node_name, time: get_block_timestamp() });
        }

        fn update_farm_name(ref self: ContractState, name: felt252){
            let caller = get_caller_address();
            assert(self.my_farm.read(caller).is_non_zero(), 'create first');
            self.my_farm.write(caller, name);
            self.emit(UpdateFarmName { owner: caller, name: name, time: get_block_timestamp() });
        }
        
        fn add_nft_to_farm(ref self: ContractState, nft_id: u256){
            let caller = get_caller_address();
            assert(self.my_farm.read(caller).is_non_zero(), 'create farm first');
            assert(self.my_chick_status.read(caller) == 0, 'already has nft');
            let nft_owner = ICHICKDispatcher { contract_address: self.chick_nft_address.read() }.owner_of(nft_id);
            assert(nft_owner == caller, 'not nft owner');
            // burn erc721 nft
            ICHICKDispatcher { contract_address: self.chick_nft_address.read() }.burn(nft_id);
            self.my_chick_id.write(caller, nft_id);
            self.burn_chick_num.write(self.burn_chick_num.read() + 1);
            self.chick_gardon_num.write(self.chick_gardon_num.read() + 1);
            self.my_chick_status.write(caller, 1); // add chick, change status
        }

        fn add_egg_to_farm(ref self: ContractState, amount: u32){
            let caller = get_caller_address();
            assert(self.my_farm.read(caller).is_non_zero(), 'create farm first');
            let _amount: u256 = amount.into();
            //burn erc1155 amount
            let egg_amount = IEGGDispatcher { contract_address: self.egg_nft_address.read() }.balance_of(caller, 1);
            assert(egg_amount >= _amount, 'not enough amount');
            IEGGDispatcher { contract_address: self.egg_nft_address.read() }.burn(caller, 1, _amount);

            let eggs = self.my_eggs.read(get_caller_address());
            self.my_eggs.write(get_caller_address(), eggs + amount);
            self.brun_egg_num.write(self.brun_egg_num.read() + _amount);
            self.egg_gardon_num.write(self.egg_gardon_num.read() + _amount);
        }
        
        fn buy_food(ref self: ContractState, food_amount: u32){
            let caller = get_caller_address();
            assert(self.my_farm.read(caller).is_non_zero(), 'create farm first');
            //burn ngt
            let _food_amount: u256 = food_amount.into();
            // IERC20Dispatcher { contract_address: self.ngt_address.read() }.transfer_from(caller, Zeroable::zero(), (self.food_price.read() * _food_amount));
            IERC20Dispatcher { contract_address: self.ngt_address.read() }.transfer_from(caller, self.burn_address.read(), (self.food_price.read() * _food_amount));
            let food = self.my_chick_food.read(caller);
            self.my_chick_food.write(caller, food + food_amount);
        }

        fn feed_chick(ref self: ContractState){
            let caller = get_caller_address();
            assert(self.my_farm.read(caller).is_non_zero(), 'create farm first');
            assert(self.my_chick_status.read(caller) == 1, 'status wrong');
            let food = self.my_chick_food.read(caller);
            assert(food >= 1, 'food not enough');
            self.my_chick_food.write(caller, food - 1);
            self.my_chick_status.write(caller, 2); // feeded, change status
            self.my_chick_update_time.write(caller, get_block_timestamp());
        }

        fn choose_egg_hatch(ref self: ContractState, _choose: u8){
            let call_addr = get_caller_address();
            assert(self.my_farm.read(call_addr).is_non_zero(), 'create farm first');
            assert(self.my_chick_status.read(call_addr) == 2, 'status wrong');
            let time = self.my_chick_update_time.read(call_addr);
            assert(get_block_timestamp() - time >= self.grow_time.read(), 'time not enough');
            if(_choose ==1 ){ // lay egg
                self.my_chick_status.write(call_addr, 3);
                //set random worm num and time
                let random_num = IRANDOMDispatcher { contract_address: self.random_address.read() }.get_random();//u64
                let _random = random_num % 4;
                let mut _randon_time = random_num % self.each_egg_time.read();
                if(_randon_time == 0){
                   _randon_time = self.each_egg_time.read()/2;
                }
                let random_ : u32 = _random.try_into().unwrap();
                self.my_worm.write(call_addr, random_);//random num
                self.my_worm_time.write(call_addr, _randon_time);//time diff
                self.laying_chick_num.write(self.laying_chick_num.read() + 1);
            }else{ //hatch
                let eggs = self.my_eggs.read(call_addr);
                assert(eggs >= self.hatch_need_egg.read(), 'eggs not enough');
                self.my_chick_status.write(call_addr, 4);
                self.my_eggs.write(call_addr, eggs - self.hatch_need_egg.read());
                //decide random chick num
                let random_num = IRANDOMDispatcher { contract_address: self.random_address.read() }.get_random();//u64
                let _random = random_num % 10;
                if(_random == 3 || _random == 7){
                   self.my_random_chick.write(call_addr, 1);//random decide 0 or 1
                }else{
                   self.my_random_chick.write(call_addr, 0);//random decide 0 or 1
                }
                
                self.hatching_chick_num.write(self.hatching_chick_num.read() + 1);
            }
            self.my_chick_update_time.write(get_caller_address(), get_block_timestamp());
        }
        fn reap_egg(ref self: ContractState, version: u8){
            let call_addr = get_caller_address();
            assert(self.my_farm.read(call_addr).is_non_zero(), 'create farm first');
            assert(self.my_chick_status.read(call_addr) == 3, 'status wrong');
            let time = self.my_chick_update_time.read(call_addr);
            let _base_egg: felt252 = self.base_egg.read().into();
            let base_egg_: u64 = _base_egg.try_into().unwrap();
            assert(get_block_timestamp() -time >= self.each_egg_time.read() * base_egg_, 'time not enough');
            let eggs = self.my_eggs.read(call_addr);
            self.my_eggs.write(call_addr, eggs + self.base_egg.read() + self.my_eat_worm.read(call_addr) - self.my_stolen_egg.read(call_addr));

            let mut _invite_income = 0_u128;
            let mut _node_income = 0_u128;
            let _egg_fee: felt252 = self.reap_egg_fee.read().try_into().unwrap();
            let _egg_fee_: u128 = _egg_fee.try_into().unwrap();
            _invite_income = _egg_fee_ * self.invite_percentage.read() / HUNDRED_PERCENT;
            _node_income = _egg_fee_ * self.node_percentage.read() / HUNDRED_PERCENT;
            let invite_income: u256 = _invite_income.into();
            let node_income: u256 = _node_income.into();

            //pay reap fee
            if(version == 0){
                IERC20Dispatcher { contract_address: self.eth20_address.read() }.transferFrom(call_addr, get_contract_address(), self.reap_egg_fee.read() - invite_income - node_income);
                IERC20Dispatcher { contract_address: self.eth20_address.read() }.transferFrom(call_addr, self.my_invite.read(call_addr), invite_income);
                IERC20Dispatcher { contract_address: self.eth20_address.read() }.transferFrom(call_addr, self.my_node.read(call_addr), node_income);
            }else{
                IERC20Dispatcher { contract_address: self.eth20_address.read() }.transfer_from(call_addr, get_contract_address(), self.reap_egg_fee.read() - invite_income - node_income);
                IERC20Dispatcher { contract_address: self.eth20_address.read() }.transfer_from(call_addr, self.my_invite.read(call_addr), invite_income);
                IERC20Dispatcher { contract_address: self.eth20_address.read() }.transfer_from(call_addr, self.my_node.read(call_addr), node_income);
            }

            if(self.laying_chick_num.read() >= 1){
                self.laying_chick_num.write(self.laying_chick_num.read() - 1);
            }
            if(self.chick_gardon_num.read() >= 1){
                self.chick_gardon_num.write(self.chick_gardon_num.read() - 1);
            }
            
            //reset state
            self.my_farm_level.write(call_addr, self.my_farm_level.read(call_addr) + 1);
            self.my_chick_id.write(call_addr, 0);
            self.my_chick_status.write(call_addr, 0);
            self.my_eat_worm.write(call_addr, 0);
            self.my_worm.write(call_addr, 0);
            self.my_worm_time.write(call_addr, 0);
            self.my_chick_update_time.write(call_addr, 0);

            self.emit(InviteEarn {earnaddr: self.my_invite.read(call_addr), fromaddr: call_addr, amount: _invite_income, time: get_block_timestamp()});
            self.emit(NodeEarn {earnaddr: self.my_node.read(call_addr), fromaddr: call_addr, amount: _node_income, time: get_block_timestamp()});
            self.emit(UpdateFarmLevel { owner: call_addr, level: self.my_farm_level.read(call_addr), time: get_block_timestamp() });
        }
        fn eat_worm(ref self: ContractState){
            let call_addr = get_caller_address();
            assert(self.my_farm.read(call_addr).is_non_zero(), 'create farm first');
            assert(self.my_chick_status.read(call_addr) == 3, 'status wrong');
            let (checks, _) = FarmInfo::check_worm_time(@self, call_addr);
            assert(checks, 'wrong time');
            let worm = self.my_eat_worm.read(call_addr);
            self.my_eat_worm.write(call_addr, worm + 1);
        }

        fn steal_egg_from_other_gardon(ref self: ContractState, from_addr: ContractAddress){
            let call_addr = get_caller_address();
            assert(self.my_farm.read(call_addr).is_non_zero(), 'farm error');
            assert(self.my_farm.read(from_addr).is_non_zero(), 'from_farm error');
            assert(self.my_chick_status.read(call_addr) == 4, 'status wrong'); //u should hatch, then can steal
            assert(self.my_chick_status.read(from_addr) == 3, 'from status wrong');
            assert(self.my_farm_level.read(call_addr) >= self.my_farm_level.read(from_addr), 'level not enough');
            //steal time need Cooling
            assert(get_block_timestamp() - self.my_steal_time.read(call_addr) >= self.steal_cooling_time.read(), 'time not allow');
            //check time
            let time = get_block_timestamp() - self.my_chick_update_time.read(from_addr);
            let _base_egg: felt252 = self.base_egg.read().into();
            let base_egg_: u64 = _base_egg.try_into().unwrap();
            assert(time >= self.each_egg_time.read() * base_egg_ + self.steal_start_time.read(), 'time not enough');
            //check stolen num
            assert(self.my_stolen_egg.read(from_addr) < self.can_stolen_egg.read(), 'stolen num max');
            self.my_eggs.write(call_addr, self.my_eggs.read(call_addr) + 1);
            self.my_stolen_egg.write(from_addr, self.my_stolen_egg.read(from_addr) + 1);
            //reset my steal time
            self.my_steal_time.write(call_addr, get_block_timestamp());
            //add stolen event
            self.emit(StealEgg { steal: call_addr, stolen: from_addr, time: get_block_timestamp()});
        }

        fn reap_chick(ref self: ContractState, version: u8){
            let call_addr = get_caller_address();
            assert(self.my_farm.read(call_addr).is_non_zero(), 'create farm first');
            assert(self.my_chick_status.read(call_addr) == 4, 'status wrong');
            let time = self.my_chick_update_time.read(call_addr);
            assert(get_block_timestamp() - time >= self.hatch_time.read(), 'time not enough');

            let mut _invite_income = 0_u128;
            let mut _node_income = 0_u128;
            let _chick_fee: felt252 = self.reap_chick_fee.read().try_into().unwrap();
            let _chick_fee_: u128 = _chick_fee.try_into().unwrap();
            _invite_income = _chick_fee_ * self.invite_percentage.read() / HUNDRED_PERCENT;
            _node_income = _chick_fee_ * self.node_percentage.read() / HUNDRED_PERCENT;
            let invite_income: u256 = _invite_income.into();
            let node_income: u256 = _node_income.into();

            //pay reap fee
            if(version == 0){
                IERC20Dispatcher { contract_address: self.eth20_address.read() }.transferFrom(call_addr, get_contract_address(), self.reap_chick_fee.read() - invite_income - node_income);
                IERC20Dispatcher { contract_address: self.eth20_address.read() }.transferFrom(call_addr, self.my_invite.read(call_addr), invite_income);
                IERC20Dispatcher { contract_address: self.eth20_address.read() }.transferFrom(call_addr, self.my_node.read(call_addr), node_income);
            }else{
                IERC20Dispatcher { contract_address: self.eth20_address.read() }.transfer_from(call_addr, get_contract_address(), self.reap_chick_fee.read() - invite_income - node_income);
                IERC20Dispatcher { contract_address: self.eth20_address.read() }.transfer_from(call_addr, self.my_invite.read(call_addr), invite_income);
                IERC20Dispatcher { contract_address: self.eth20_address.read() }.transfer_from(call_addr, self.my_node.read(call_addr), node_income);
            }
            //create erc721 nft
            let mut nft_num = 0;
            if(self.random_chick.read()){
                //base_chick + self.my_random_chick.read(call_addr)
                nft_num = self.base_chick.read() + self.my_random_chick.read(call_addr);

                //reset random chick
                self.my_random_chick.write(call_addr, 0);
            }else{
                //base_chick
                nft_num = self.base_chick.read();
            }

            let mut i = 0; 
            loop {
                if i >= nft_num {
                    break;
                }
                ICHICKDispatcher { contract_address: self.chick_nft_address.read() }.mint(call_addr);
                i += 1;
            };

            if(self.hatching_chick_num.read() >= 1){
                self.hatching_chick_num.write(self.hatching_chick_num.read() - 1);
            }
            if(self.chick_gardon_num.read() >= 1){
                self.chick_gardon_num.write(self.chick_gardon_num.read() - 1);
            }

            //reset state
            self.my_farm_level.write(call_addr, self.my_farm_level.read(call_addr) + 1);
            self.my_chick_id.write(call_addr, 0);
            self.my_chick_status.write(call_addr, 0);
            self.my_chick_update_time.write(call_addr, 0);

            self.emit(InviteEarn {earnaddr: self.my_invite.read(call_addr), fromaddr: call_addr, amount: _invite_income, time: get_block_timestamp()});
            self.emit(NodeEarn {earnaddr: self.my_node.read(call_addr), fromaddr: call_addr, amount: _node_income, time: get_block_timestamp()});
            self.emit(UpdateFarmLevel { owner: call_addr, level: self.my_farm_level.read(call_addr), time: get_block_timestamp() });
        }

        fn egg_to_nft(ref self: ContractState, amount: u32){
            let call_addr = get_caller_address();
            assert(self.my_farm.read(call_addr).is_non_zero(), 'create farm first');
            let eggs = self.my_eggs.read(call_addr);
            assert(eggs >= amount, 'eggs not enough');
            self.my_eggs.write(call_addr, eggs - amount);
            //create amount erc1155 eggs
            let _amount:u256 = amount.into();
            IEGGDispatcher { contract_address: self.egg_nft_address.read() }.mint(call_addr, 1, _amount);
            if(self.egg_gardon_num.read() >= _amount){
                self.egg_gardon_num.write(self.egg_gardon_num.read() - _amount);
            }
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

    #[external(v0)]
    impl FarmSet of interface::IFarmSet<ContractState> {
        fn set_nft_address(ref self: ContractState, _chick_nft_address: ContractAddress, _egg_nft_address: ContractAddress){
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'not owner');
            self.chick_nft_address.write(_chick_nft_address);
            self.egg_nft_address.write(_egg_nft_address);
        }

        fn set_ngt_eth20_address(ref self: ContractState, _ngt_address: ContractAddress, _eth20_address: ContractAddress){
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'not owner');
            self.ngt_address.write(_ngt_address);
            self.eth20_address.write(_eth20_address);
        }

        fn set_random_address(ref self: ContractState, _random_address: ContractAddress){
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'not owner');
            self.random_address.write(_random_address);
        }

        fn set_burn_address(ref self: ContractState, _burn_address: ContractAddress){
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'not owner');
            self.burn_address.write(_burn_address);
        }

        fn set_food_node_price(ref self: ContractState, _food_price: u256, _node_price: u256){
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'not owner');
            self.food_price.write(_food_price);
            self.node_price.write(_node_price);
        }

        fn set_hatch_need_egg(ref self: ContractState, _hatch_need_egg: u32){
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'not owner');
            self.hatch_need_egg.write(_hatch_need_egg);
        }
        fn set_grow_hatch_time(ref self: ContractState, _grow_time: u64, _hatch_time: u64){
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'not owner');
            self.grow_time.write(_grow_time);
            self.hatch_time.write(_hatch_time);
        }
        fn set_each_egg_time(ref self: ContractState, _each_egg_time: u64){
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'not owner');
            self.each_egg_time.write(_each_egg_time);
        }
        fn set_steal_start_time(ref self: ContractState, _steal_start_time: u64){
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'not owner');
            self.steal_start_time.write(_steal_start_time);
        }
        fn set_worm_sustain_time(ref self: ContractState, _worm_sustain_time: u64){
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'not owner');
            self.worm_sustain_time.write(_worm_sustain_time);
        }
        fn set_base_egg_chick(ref self: ContractState, _base_egg: u32, _base_chick: u32){
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'not owner');
            self.base_egg.write(_base_egg);
            self.base_chick.write(_base_chick);
        }
        fn set_stolen_cooling_egg(ref self: ContractState, _can_stolen_egg: u32, _steal_cooling_time: u64){
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'not owner');
            self.can_stolen_egg.write(_can_stolen_egg);
            self.steal_cooling_time.write(_steal_cooling_time);
        }
        fn set_random_chick(ref self: ContractState, _random_chick: bool){
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'not owner');
            self.random_chick.write(_random_chick);
        }

        fn set_whitelist(ref self: ContractState, _white_address: ContractAddress, _trueornot: bool){
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'not owner');
            self.node_whitelist.write(_white_address, _trueornot);
        }

        fn set_percentage(ref self: ContractState, _invite_percentage: u128, _node_percentage: u128){
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'not owner');
            self.invite_percentage.write(_invite_percentage);
            self.node_percentage.write(_node_percentage);
        }

        fn set_reap_fee(ref self: ContractState, _reap_egg_fee: u256, _reap_chick_fee: u256){
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'not owner');
            self.reap_egg_fee.write(_reap_egg_fee);
            self.reap_chick_fee.write(_reap_chick_fee);
        }
    }

    #[external(v0)]
    impl FarmInfo of interface::IFarmInfo<ContractState> {
        fn check_worm_time(self: @ContractState, call_addr: ContractAddress) -> (bool, u32){
            let time = get_block_timestamp() - self.my_chick_update_time.read(call_addr);
            let mut i = self.my_eat_worm.read(call_addr);
            let _num = self.my_worm.read(call_addr);
            let mut worm_time = false;
            let diff = self.my_worm_time.read(call_addr);
            let mut indexs: u32 = i; 
            loop {
                if i >= _num {
                    // if(indexs == _num){
                    //     indexs = 0;
                    // }
                    break;
                }

                if(time >= (i+1).into() * diff){
                   indexs = i+1;
                }
                
                if ((time >= (i+1).into() * diff) && (time <= (i+1).into() * diff + self.worm_sustain_time.read())) {
                    worm_time = true;
                    break;
                }
                
                i += 1;
                
            };
            (worm_time, indexs)
        }

        fn get_hatch_chick_num(self: @ContractState, addr: ContractAddress) -> u32{
            let mut num: u32 = 0;
            if(get_block_timestamp() >= self.hatch_time.read() + self.my_chick_update_time.read(addr)){
                if(self.my_chick_status.read(addr) == 4){
                    if(self.random_chick.read()){
                        num = self.base_chick.read() + self.my_random_chick.read(addr);
                    }else{
                        num = self.base_chick.read();
                    }
                }
            }
            num
        }

        fn get_chick_info(self: @ContractState, contract_address: ContractAddress) ->ChickInfo{
            let infos = ChickInfo{  my_farm_level: self.my_farm_level.read(contract_address),
                                    my_chick_id: self.my_chick_id.read(contract_address),
                                    chick_status: self.my_chick_status.read(contract_address),
                                    eggs: self.my_eggs.read(contract_address),
                                    chick_food: self.my_chick_food.read(contract_address),
                                    my_stolen: self.my_stolen_egg.read(contract_address),
                                    my_worms: self.my_worm.read(contract_address),
                                    my_eat_worms: self.my_eat_worm.read(contract_address),
                                    update_time: self.my_chick_update_time.read(contract_address),
                                    block_chain_time: get_block_timestamp(),
                                    grow_time: self.grow_time.read(),
                                    hatch_time: self.hatch_time.read(),
                                    each_egg_time: self.each_egg_time.read(),
                                    farm_name: self.my_farm.read(contract_address),
                                    food_price: self.food_price.read(),
                                    node_price: self.node_price.read(),
                                    reap_egg_fee: self.reap_egg_fee.read(),
                                    reap_chick_fee: self.reap_chick_fee.read(),
                                    base_egg: self.base_egg.read(),};
            infos
        }

        fn get_num_info(self: @ContractState) ->NumInfo{
            let infos = NumInfo{    burn_chick_num: self.burn_chick_num.read(),
                                    brun_egg_num: self.brun_egg_num.read(),
                                    chick_gardon_num: self.chick_gardon_num.read(),
                                    hatching_chick_num: self.hatching_chick_num.read(),
                                    laying_chick_num: self.laying_chick_num.read(),
                                    egg_gardon_num: self.egg_gardon_num.read(),
                                    };
            infos
        }

        fn get_owner(self: @ContractState) -> ContractAddress{
            self.owner.read()
        }

        fn get_node_name(self: @ContractState, contract_address: ContractAddress) -> felt252{
            self.node_name.read(contract_address)
        }
        fn get_my_node_name(self: @ContractState, invite_address: ContractAddress) -> (ContractAddress, felt252){
            let _node = self.my_node.read(invite_address);
            let _name = self.node_name.read(_node);
            (_node, _name)
        }
    }

}