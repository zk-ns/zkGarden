#[starknet::contract]
mod ERC1155 {
  use array::{ Span, ArrayTrait, SpanTrait, ArrayDrop, SpanSerde };
  use option::OptionTrait;
  use traits::{ Into, TryInto };
  use starknet::contract_address::ContractAddressZeroable;
  use zeroable::Zeroable;
  use starknet::ContractAddress;
  use starknet::ClassHash;
  use starknet::get_caller_address;
  use zkGarden::egg::interface::DualCaseSRC5DispatcherTrait;
  use zkGarden::egg::interface::DualCaseSRC5Dispatcher;
  use zkGarden::egg::interface::ERC1155ReceiverDispatcherTrait;
  use zkGarden::egg::interface::ERC1155ReceiverDispatcher;
  use zkGarden::egg::interface;
  use zkGarden::storage::StoreSpanFelt252;

  const HUNDRED_PERCENT: u128 = 10000;

  //
  // Storage
  //

  #[storage]
  struct Storage {
    _balances: LegacyMap<(u256, ContractAddress), u256>,
    _operator_approvals: LegacyMap<(ContractAddress, ContractAddress), bool>,
    _uri: Span<felt252>,
    owner: ContractAddress,
    friend: ContractAddress,
    free_mint_friend: ContractAddress,
    _royalties_receiver: ContractAddress,
    _royalties_percentage: u128,
    ERC1155_total_supply: LegacyMap<u256, u256>,
  }

  //
  // Events
  //

  #[event]
  #[derive(Drop, starknet::Event)]
  enum Event {
    TransferSingle: TransferSingle,
    TransferBatch: TransferBatch,
    ApprovalForAll: ApprovalForAll,
    URI: URI,
    Upgraded: Upgraded,
  }

  #[derive(Drop, starknet::Event)]
  struct Upgraded {
      class_hash: ClassHash
  }

  #[derive(Drop, starknet::Event)]
  struct TransferSingle {
    operator: ContractAddress,
    from: ContractAddress,
    to: ContractAddress,
    id: u256,
    value: u256,
  }

  #[derive(Drop, starknet::Event)]
  struct TransferBatch {
    operator: ContractAddress,
    from: ContractAddress,
    to: ContractAddress,
    ids: Span<u256>,
    values: Span<u256>,
  }

  #[derive(Drop, starknet::Event)]
  struct ApprovalForAll {
    account: ContractAddress,
    operator: ContractAddress,
    approved: bool,
  }

  #[derive(Drop, starknet::Event)]
  struct URI {
    value: Span<felt252>,
    id: u256,
  }

  //
  // Constructor
  //

  #[constructor]
  fn constructor(ref self: ContractState, _owner: ContractAddress) {
    self.initializer();
    self.owner.write(_owner);
  }

  //
  // IERC1155 impl
  //

  #[external(v0)]
  impl ERC1155Impl of interface::IERC1155<ContractState> {
    fn uri(self: @ContractState, token_id: u256) -> Span<felt252> {
      self._uri.read()
    }

    fn balance_of(self: @ContractState, account: ContractAddress, id: u256) -> u256 {
      self._balances.read((id, account))
    }

    fn balance_of_batch(
      self: @ContractState,
      accounts: Span<ContractAddress>,
      ids: Span<u256>
    ) -> Span<u256> {
      assert(accounts.len() == ids.len(), 'ERC1155: bad accounts & ids len');

      let mut batch_balances = array![];

      let mut i: usize = 0;
      let len = accounts.len();
      loop {
        if (i >= len) {
          break ();
        }

        batch_balances.append(self.balance_of(*accounts.at(i), *ids.at(i)));
        i += 1;
      };

      batch_balances.span()
    }

    fn is_approved_for_all(
      self: @ContractState,
      owner: ContractAddress,
      operator: ContractAddress
    ) -> bool {
      self._operator_approvals.read((owner, operator))
    }

    fn set_approval_for_all(ref self: ContractState, operator: ContractAddress, approved: bool) {
      let caller = starknet::get_caller_address();

      self._set_approval_for_all(caller, operator, approved);
    }

    fn safe_transfer_from(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      id: u256,
      amount: u256,
      data: Span<felt252>
    ) {
      let caller = starknet::get_caller_address();
      assert(
        (from == caller) | self.is_approved_for_all(from, caller),
        'ERC1155: caller not allowed'
      );

      self._safe_transfer_from(from, to, id, amount, data);
    }

    fn safe_batch_transfer_from(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      ids: Span<u256>,
      amounts: Span<u256>,
      data: Span<felt252>
    ) {
      let caller = starknet::get_caller_address();
      assert(
        (from == caller) | self.is_approved_for_all(from, caller),
        'ERC1155: caller not allowed'
      );

      self._safe_batch_transfer_from(from, to, ids, amounts, data);
    }

    fn transfer_from(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      id: u256,
      amount: u256,
    ) {
      let caller = starknet::get_caller_address();
      assert(
        (from == caller) | self.is_approved_for_all(from, caller),
        'ERC1155: caller not allowed'
      );

      self._transfer_from(from, to, id, amount);
    }

    fn batch_transfer_from(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      ids: Span<u256>,
      amounts: Span<u256>,
    ) {
      let caller = starknet::get_caller_address();
      assert(
        (from == caller) | self.is_approved_for_all(from, caller),
        'ERC1155: caller not allowed'
      );

      self._batch_transfer_from(:from, :to, :ids, :amounts);
    }

    fn supports_interface(self: @ContractState, interface_id: felt252) -> bool {
      
        (interface_id == interface::IERC1155_ID) |
        (interface_id == interface::IERC1155_METADATA_ID) |
        (interface_id == interface::OLD_IERC1155_ID) |
        (interface_id == interface::IERC2981_ID) |
        (interface_id == interface::ISRC6_ID)  // add to receive nft
    }

    fn mint(ref self: ContractState, to: ContractAddress, id: u256, amount: u256){
        let caller = get_caller_address();
        assert(caller == self.friend.read(), 'not friend');
        self._unsafe_mint(to, id, amount);
    }

    fn free_mint(ref self: ContractState, to: ContractAddress, id: u256, amount: u256){
        let caller = get_caller_address();
        assert(caller == self.free_mint_friend.read(), 'not friend');
        self._unsafe_mint(to, id, amount);
    }

    fn set_friend(ref self: ContractState, _friend: ContractAddress){
        let caller = get_caller_address();
        assert(caller == self.owner.read(), 'not owner');
        self.friend.write(_friend);
    }

    fn set_free_mint_friend(ref self: ContractState, _friend: ContractAddress){
        let caller = get_caller_address();
        assert(caller == self.owner.read(), 'not owner');
        self.free_mint_friend.write(_friend);
    }

    fn burn(ref self: ContractState, from: ContractAddress, id: u256, amount: u256) {
        let caller = get_caller_address();
        assert(caller == self.friend.read(), 'not friend'); 
        assert(
          (from == caller) | self.is_approved_for_all(from, caller),
          'ERC1155: caller not allowed'
        );
        self._burn(from, id, amount);
    }
    
    fn total_supply(self: @ContractState, id: u256)->u256{
        self.ERC1155_total_supply.read(id)
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
  impl ERC1155CamelOnlyImpl of interface::IERC1155CamelOnly<ContractState> {
    fn balanceOf(self: @ContractState, account: ContractAddress, id: u256) -> u256{
       ERC1155Impl::balance_of(self, account, id)
    }

    fn balanceOfBatch(self: @ContractState, accounts: Span<ContractAddress>, ids: Span<u256>) -> Span<u256>{
       ERC1155Impl::balance_of_batch(self, accounts, ids)
    }

    fn isApprovedForAll(
        self: @ContractState,
        account: ContractAddress,
        operator: ContractAddress
    ) -> bool{
       ERC1155Impl::is_approved_for_all(self, account, operator)
    }

    fn setApprovalForAll(ref self: ContractState, operator: ContractAddress, approved: bool){
       ERC1155Impl::set_approval_for_all(ref self, operator, approved);
    }

    fn safeTransferFrom(
        ref self: ContractState,
        from: ContractAddress,
        to: ContractAddress,
        id: u256,
        amount: u256,
        data: Span<felt252>
    ){
       ERC1155Impl::safe_transfer_from(ref self, from, to, id, amount, data);
    }

    fn safeBatchTransferFrom(
        ref self: ContractState,
        from: ContractAddress,
        to: ContractAddress,
        ids: Span<u256>,
        amounts: Span<u256>,
        data: Span<felt252>
    ){
       ERC1155Impl::safe_batch_transfer_from(ref self, from, to, ids, amounts, data);
    }

    fn transferFrom(
        ref self: ContractState,
        from: ContractAddress,
        to: ContractAddress,
        id: u256,
        amount: u256,
    ){
       ERC1155Impl::transfer_from(ref self, from, to, id, amount);
    }

    fn batchTransferFrom(
        ref self: ContractState,
        from: ContractAddress,
        to: ContractAddress,
        ids: Span<u256>,
        amounts: Span<u256>,
    ){
       ERC1155Impl::batch_transfer_from(ref self, from, to, ids, amounts);
    }

    fn supportsInterface(self: @ContractState, interface_id: felt252) -> bool {
       ERC1155Impl::supports_interface(self, interface_id)
    }
  }

    #[external(v0)]
    impl IERC2981Impl of interface::IERC2981<ContractState> {
        //support 10**34 sale_price
        fn royalty_info(self: @ContractState, token_id: u256, sale_price: u256) -> (ContractAddress, u256) {
            assert(sale_price > 0, 'Unsupported sale price');

            let royalties_receiver_ = self._royalties_receiver.read();
            let royalties_percentage_ = self._royalties_percentage.read();

            let mut royalty_amount = 0_u128;
            let _sale_price: felt252 = sale_price.try_into().unwrap();
            let _sale_price_: u128 = _sale_price.try_into().unwrap();
            royalty_amount = _sale_price_ * royalties_percentage_ / HUNDRED_PERCENT;
            let royalty_amount_:u256 = royalty_amount.into();
            (royalties_receiver_, royalty_amount_)
        }
    }

    #[external(v0)]
    impl IERC2981CamelOnlyImpl of interface::IERC2981CamelOnly<ContractState> {
        fn royaltyInfo(self: @ContractState, token_id: u256, sale_price: u256) -> (ContractAddress, u256) {
            IERC2981Impl::royalty_info(self, token_id, sale_price)
        }
    }
    
    #[external(v0)]
    fn set_royalty_receiver(ref self: ContractState, new_receiver: ContractAddress) {
        let caller = get_caller_address();
        assert(caller == self.owner.read(), 'not owner');
        self._royalties_receiver.write(new_receiver);
    }

    #[external(v0)]
    fn set_royalty_percentage(ref self: ContractState, new_percentage: u128) {
        assert(new_percentage <= HUNDRED_PERCENT, 'Invalid percentage');
        let caller = get_caller_address();
        assert(caller == self.owner.read(), 'not owner');
        self._royalties_percentage.write(new_percentage);
    }

  //
  // Internals
  //

  #[generate_trait]
  impl InternalImpl of InternalTrait {
    fn initializer(ref self: ContractState) {
      let mut uri_ = ArrayTrait::new();
      uri_.append('https://ipfs.io/ipfs/bafkrei');
      uri_.append('cmeharxprhocrmxfdeemw7r57vid');
      uri_.append('hbbsuapuy7qgdnmhtxwnx7v4');
      self._set_uri(uri_.span());
    }

    fn _mint(ref self: ContractState, to: ContractAddress, id: u256, amount: u256, data: Span<felt252>) {
      assert(to.is_non_zero(), 'ERC1155: mint to 0 addr');
      let (ids, amounts) = self._as_singleton_spans(id, amount);
      self._safe_update(Zeroable::zero(), to, ids, amounts, data);
      self.ERC1155_total_supply.write(id, self.ERC1155_total_supply.read(id) + amount);
    }

    fn _unsafe_mint(ref self: ContractState, to: ContractAddress, id: u256, amount: u256) {
      assert(to.is_non_zero(), 'ERC1155: mint to 0 addr');
      let (ids, amounts) = self._as_singleton_spans(id, amount);
      self._update(Zeroable::zero(), to, ids, amounts);
      self.ERC1155_total_supply.write(id, self.ERC1155_total_supply.read(id) + amount);
    }

    fn _mint_batch(
      ref self: ContractState,
      to: ContractAddress,
      ids: Span<u256>,
      amounts: Span<u256>,
      data: Span<felt252>
    ) {
      assert(to.is_non_zero(), 'ERC1155: mint to 0 addr');
      self._safe_update(Zeroable::zero(), to, ids, amounts, data);
    }

    // Burn

    fn _burn(ref self: ContractState, from: ContractAddress, id: u256, amount: u256) {
      assert(from.is_non_zero(), 'ERC1155: burn from 0 addr');
      let (ids, amounts) = self._as_singleton_spans(id, amount);
      self._update(from, Zeroable::zero(), ids, amounts);
    }

    fn _burn_batch(ref self: ContractState, from: ContractAddress, ids: Span<u256>, amounts: Span<u256>) {
      assert(from.is_non_zero(), 'ERC1155: burn from 0 addr');
      self._update(from, Zeroable::zero(), ids, amounts);
    }

    // Setters

    fn _set_uri(ref self: ContractState, new_uri: Span<felt252>) {
      self._uri.write(new_uri);
    }

    fn _set_approval_for_all(
      ref self: ContractState,
      owner: ContractAddress,
      operator: ContractAddress,
      approved: bool
    ) {
      assert(owner != operator, 'ERC1155: self approval');

      self._operator_approvals.write((owner, operator), approved);

      // Events
      self.emit(
        Event::ApprovalForAll(
          ApprovalForAll { account: owner, operator, approved }
        )
      );
    }

    // Balances update

    fn _safe_update(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      mut ids: Span<u256>,
      amounts: Span<u256>,
      data: Span<felt252>
    ) {
      //update first
      self._update(from, to, ids, amounts);

      let operator = starknet::get_caller_address();

      // Safe transfer check
      if (to.is_non_zero()) {
        if (ids.len() == 1) {
          let id = *ids.at(0);
          let amount = *amounts.at(0);
          
          assert(
                self._check_on_erc1155_received(operator, from, to, id, amount, data), 'ERC1155: safe transfer failed'
            );
          
        } else {
          
          assert(
                self._check_on_erc1155_batch_received(operator, from, to, ids, amounts, data), 'batch safe transfer failed'
            );
          
        }
      }
    }

    fn _update(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      mut ids: Span<u256>,
      amounts: Span<u256>,
    ) {
      assert(ids.len() == amounts.len(), 'ERC1155: bad ids & amounts len');

      let operator = starknet::get_caller_address();

      let mut i: usize = 0;
      let len = ids.len();
      loop {
        if (i >= len) {
          break ();
        }

        let id = *ids.at(i);
        let amount = *amounts.at(i);

        // Decrease sender balance
        if (from.is_non_zero()) {
          let from_balance = self._balances.read((id, from));
          assert(from_balance >= amount, 'ERC1155: insufficient balance');

          self._balances.write((id, from), from_balance - amount);
        }

        // Increase recipient balance
        if (to.is_non_zero()) {
          let to_balance = self._balances.read((id, to));
          self._balances.write((id, to), to_balance + amount);
        }

        i += 1;
      };

      // Transfer events
      if (ids.len() == 1) {
        let id = *ids.at(0);
        let amount = *amounts.at(0);

        self.emit(
          Event::TransferSingle(
            TransferSingle { operator, from, to, id, value: amount }
          )
        );
      } else {
        self.emit(
          Event::TransferBatch(
            TransferBatch { operator, from, to, ids, values: amounts }
          )
        );
      }
    }

    // Safe transfers

    fn _safe_transfer_from(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      id: u256,
      amount: u256,
      data: Span<felt252>
    ) {
      assert(to.is_non_zero(), 'ERC1155: transfer to 0 addr');
      assert(from.is_non_zero(), 'ERC1155: transfer from 0 addr');

      let (ids, amounts) = self._as_singleton_spans(id, amount);

      self._safe_update(from, to, ids, amounts, data);
    }

    fn _safe_batch_transfer_from(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      ids: Span<u256>,
      amounts: Span<u256>,
      data: Span<felt252>
    ) {
      assert(to.is_non_zero(), 'ERC1155: transfer to 0 addr');
      assert(from.is_non_zero(), 'ERC1155: transfer from 0 addr');

      self._safe_update(from, to, ids, amounts, data);
    }

    // Unsafe transfers

    fn _transfer_from(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      id: u256,
      amount: u256,
    ) {
      assert(to.is_non_zero(), 'ERC1155: transfer to 0 addr');
      assert(from.is_non_zero(), 'ERC1155: transfer from 0 addr');

      let (ids, amounts) = self._as_singleton_spans(id, amount);

      self._update(from, to, ids, amounts);
    }

    fn _batch_transfer_from(
      ref self: ContractState,
      from: ContractAddress,
      to: ContractAddress,
      ids: Span<u256>,
      amounts: Span<u256>,
    ) {
      assert(to.is_non_zero(), 'ERC1155: transfer to 0 addr');
      assert(from.is_non_zero(), 'ERC1155: transfer from 0 addr');

      self._update(from, to, ids, amounts);
    }

    // Safe transfer check

    fn _check_on_erc1155_received(
        self: @ContractState, operator: ContractAddress, from: ContractAddress, to: ContractAddress, id: u256, amount: u256, data: Span<felt252>
    ) -> bool {
        if (DualCaseSRC5Dispatcher { contract_address: to }
            .supports_interface(interface::IERC1155_RECEIVER_ID)) {
            ERC1155ReceiverDispatcher { contract_address: to }
                .on_erc1155_received(
                   operator , from, id, amount, data
                ) == interface::ON_ERC1155_RECEIVED_SELECTOR
        } else {
            DualCaseSRC5Dispatcher { contract_address: to }.supports_interface(interface::ISRC6_ID)
        }
    }

    fn _check_on_erc1155_batch_received(
        self: @ContractState, operator: ContractAddress, from: ContractAddress, to: ContractAddress, ids: Span<u256>, amounts: Span<u256>, data: Span<felt252>
    ) -> bool {
        if (DualCaseSRC5Dispatcher { contract_address: to }
            .supports_interface(interface::IERC1155_RECEIVER_ID)) {
            ERC1155ReceiverDispatcher { contract_address: to }
                .on_erc1155_batch_received(
                    operator, from, ids, amounts, data
                ) == interface::ON_ERC1155_BATCH_RECEIVED_SELECTOR
        } else {
            DualCaseSRC5Dispatcher { contract_address: to }.supports_interface(interface::ISRC6_ID)
        }
    }

    fn _as_singleton_spans(self: @ContractState, element1: u256, element2: u256) -> (Span<u256>, Span<u256>) {
      (array![element1].span(), array![element2].span())
    }
  }
}