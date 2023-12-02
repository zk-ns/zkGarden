use array::SpanSerde;
use starknet::ContractAddress;
use starknet::ClassHash;

const IERC721_ID: felt252 = 0x33eb2f84c309543403fd69f0d0f363781ef06ef6faeb0131ff16ea3175bd943;
const IERC721_METADATA_ID: felt252 = 0x6069a70848f907fa57668ba1875164eb4dcee693952468581406d131081bbd;
const IERC721_RECEIVER_ID: felt252 = 0x3a0dff5f70d80458ad14ae37bb182a728e3c8cdda0402a5daa86620bdf910bc;
const ISRC6_ID: felt252 = 0x2ceccef7f994940b3962a6c67e0ba4fcd37df7d131417c604f91e03caecc1cd;
const IERC2981_ID: felt252 = 0x2d3414e45a8700c29f119a54b9f11dca0e29e06ddcb214018fc37340e165ed6;

#[starknet::interface]
trait IERC721<TState> {
    fn name(self: @TState) -> felt252;
    fn symbol(self: @TState) -> felt252;
    fn token_uri(self: @TState, token_id: u256) -> Array<felt252>;
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn owner_of(self: @TState, token_id: u256) -> ContractAddress;
    // fn transfer(ref self: TState, to: ContractAddress, token_id: u256);
    fn transfer_from(ref self: TState, from: ContractAddress, to: ContractAddress, token_id: u256);
    fn safe_transfer_from(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>
    );
    fn approve(ref self: TState, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(ref self: TState, operator: ContractAddress, approved: bool);
    fn get_approved(self: @TState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(
        self: @TState, owner: ContractAddress, operator: ContractAddress
    ) -> bool;
    fn mint(ref self: TState, to: ContractAddress);
    fn free_mint(ref self: TState, to: ContractAddress);
    fn burn(ref self: TState, token_id: u256);
    fn total_supply(self: @TState)->u256;
    fn supports_interface(self: @TState, interface_id: felt252) -> bool;
    fn set_friend(ref self: TState, _friend: ContractAddress);
    fn set_free_mint_friend(ref self: TState, _friend: ContractAddress);
    fn upgrade(ref self: TState, new_class_hash: ClassHash);
}

#[starknet::interface]
trait IERC721CamelOnly<TContractState> {
  fn balanceOf(self: @TContractState, account: starknet::ContractAddress) -> u256;

  fn ownerOf(self: @TContractState, tokenId: u256) -> starknet::ContractAddress;

  fn getApproved(self: @TContractState, tokenId: u256) -> starknet::ContractAddress;

  fn isApprovedForAll(
    self: @TContractState,
    owner: starknet::ContractAddress,
    operator: starknet::ContractAddress
  ) -> bool;

  fn transferFrom(
    ref self: TContractState,
    from: starknet::ContractAddress,
    to: starknet::ContractAddress,
    tokenId: u256
  );

  fn safeTransferFrom(
    ref self: TContractState,
    from: starknet::ContractAddress,
    to: starknet::ContractAddress,
    tokenId: u256,
    data: Span<felt252>
  );

  fn supportsInterface(self: @TContractState, interface_id: felt252) -> bool;

  fn setApprovalForAll(ref self: TContractState, operator: starknet::ContractAddress, approved: bool);

  fn tokenUri(self: @TContractState, tokenId: u256) -> Array<felt252>;
  fn totalSupply(self: @TContractState) ->u256;
}


// ERC721 Receiver

#[starknet::interface]
trait DualCaseERC721Receiver<TState> {
    fn on_erc721_received(
        self: @TState,
        operator: starknet::ContractAddress,
        from: starknet::ContractAddress,
        token_id: u256,
        data: Span<felt252>
    ) -> felt252;

    fn onERC721Received(
        ref self: TState,
        operator: starknet::ContractAddress,
        from: starknet::ContractAddress,
        tokenId: u256,
        data: Span<felt252>
    ) -> felt252;
}

#[starknet::interface]
trait DualCaseSRC5<TState> {
    fn supports_interface(self: TState, interface_id: felt252) -> bool;
}

#[starknet::interface]
trait IERC2981<TContractState> {
  fn royalty_info(self: @TContractState, token_id: u256, sale_price: u256) -> (starknet::ContractAddress, u256);
}

#[starknet::interface]
trait IERC2981CamelOnly<TContractState> {
  fn royaltyInfo(self: @TContractState, token_id: u256, sale_price: u256) -> (starknet::ContractAddress, u256);
}