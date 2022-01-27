#!ic-repl
load "prelude.sh";

// This won't be needed once replica supports custom section
import fake = "2vxsx-fae" as "../.dfx/local/canisters/dao/dao.did";

let wasm = file "../.dfx/local/canisters/dao/dao.wasm";

identity alice;
identity bob;
identity cathy;
identity dory;
identity eve;
identity genesis;

// init args
let init = encode fake.__init_args(opt record {
  transfer_fee = record { amount_e8s = 0 };
  proposal_vote_threshold = record { amount_e8s = 500 };
  proposal_submission_deposit = record { amount_e8s = 100 };
});
let DAO = install(wasm, init, null);

// cannot update system params without proposal
let update_transfer_fee = record { transfer_fee = opt record { amount_e8s = 10_000 : nat } };
call DAO.update_system_params(update_transfer_fee);

// distribute tokens
let _ = call DAO.transfer(record { to = alice; amount = record { amount_e8s = 100 } });
let _ = call DAO.transfer(record { to = bob; amount = record { amount_e8s = 200 } });
let _ = call DAO.transfer(record { to = cathy; amount = record { amount_e8s = 300 } });
let _ = call DAO.transfer(record { to = dory; amount = record { amount_e8s = 400 } });
call DAO.account_balance();
// verify no transfer fee
assert _.amount_e8s == (999_999_999_000 : nat);

// alice makes a proposal
identity alice;
call DAO.account_balance();
assert _.amount_e8s == (100 : nat);
call DAO.submit_proposal(
  record {
    canister_id = DAO;
    method = "update_system_params";
    message = encode (update_transfer_fee);
  },
);
let alice_id = _.ok;
call DAO.account_balance();
assert _.amount_e8s == (0 : nat);

// voting
call DAO.vote(record { proposal_id = alice_id; vote = variant { yes } });
assert _.ok == variant { open };
identity eve;
call DAO.vote(record { proposal_id = alice_id; vote = variant { yes } });
assert _.err ~= "Caller does not have any tokens to vote with";
identity bob;
call DAO.get_proposal(alice_id);
assert _? ~= record {
  id = alice_id;
  proposer = alice;
  voters = opt record { alice; null : opt null };
  votes_yes = record { amount_e8s = 0 : nat };
  votes_no = record { amount_e8s = 0 : nat };
  state = variant { open };
  payload = record {
    canister_id = DAO;
    method = "update_system_params";
  };
};
call DAO.vote(record { proposal_id = alice_id; vote = variant { yes } });
assert _.ok == variant { open };
call DAO.vote(record { proposal_id = alice_id; vote = variant { no } });
assert _.err ~= "Already voted";
identity dory;
call DAO.vote(record { proposal_id = alice_id; vote = variant { no } });
assert _.ok == variant { open };
identity cathy;
call DAO.vote(record { proposal_id = alice_id; vote = variant { yes } });
assert _.ok == variant { accepted };
identity genesis;
call DAO.vote(record { proposal_id = alice_id; vote = variant { no } });
assert _.err ~= "is not open for voting";

// refunded
identity alice;
call DAO.account_balance();
assert _.amount_e8s == (100 : nat);

call DAO.get_proposal(alice_id);
assert _? ~= record {
  votes_yes = record { amount_e8s = 500 : nat };
  votes_no = record { amount_e8s = 400 : nat };
  voters = opt record { cathy; opt record { dory; opt record { bob; opt record { alice; null : opt null }}}};
};

// TODO check proposal is executed

// bob makes proposals
identity bob;
call DAO.submit_proposal(
  record {
    canister_id = DAO;
    method = "transfer";
    message = encode (record { to = alice; amount = record { amount_e8s = 100 : nat } });
  },
);
let bob1 = _.ok;
call DAO.submit_proposal(
  record {
    canister_id = DAO;
    method = "transfer";
    message = encode (record { to = alice; amount = record { amount_e8s = 100 : nat } });
  },
);
let bob2 = _.ok;
call DAO.submit_proposal(
  record {
    canister_id = DAO;
    method = "transfer";
    message = encode (record { to = alice; amount = record { amount_e8s = 100 : nat } });
  },
);
assert _.err ~= "Caller's account must have at least";

// reject bob1, accept bob2
identity cathy;
call DAO.vote(record { proposal_id = bob1; vote = variant { no } });
call DAO.vote(record { proposal_id = bob2; vote = variant { yes } });
identity dory;
call DAO.vote(record { proposal_id = bob1; vote = variant { no } });
assert _.ok == variant { rejected };
call DAO.vote(record { proposal_id = bob2; vote = variant { yes } });
assert _.ok == variant { accepted };

// bob gets only one refund
identity bob;
call DAO.account_balance();
assert _.amount_e8s == (100 : nat);

// upgrade preserves data
identity genesis;
upgrade(DAO, wasm, encode(null));
call DAO.list_proposals();
assert _[0].state == variant { succeeded };
assert _[1].state == variant { rejected };
assert _[2].state == variant { succeeded };
