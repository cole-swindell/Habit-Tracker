Habit Tracker with Escrow Contract

Overview

This Habit Tracker with Escrow Contract is a smart contract built in Clarity for the Stacks blockchain.
It encourages users to build consistent habits by staking STX tokens as commitment collateral.
Users recover their staked tokens only if they successfully log their habit over the required period.
If they fail, the contract owner can claim the forfeited stake.

🎯 Core Features
1. Create Habit

Users can start a new habit by staking a specific amount of STX tokens.

Each habit includes:

A description

Stake amount

Required log count

Duration in days

Once created, the contract locks the stake in escrow until completion.

2. Log Habit Progress

The user must log their habit daily.

Logs are tracked using block height to ensure one log per day.

If a log already exists for the day, the user cannot log again.

3. Claim Refund

After the habit period ends, if the user meets or exceeds the required log count:

Their stake is refunded.

The habit is marked as inactive.

4. Claim Forfeit (by Owner)

If the user fails to meet the goal:

The contract owner can claim the forfeited stake after the habit ends.

The habit is marked inactive.

5. User Balances

Each user’s total staked balance is recorded for transparency and validation.

🧩 Data Structures
Type	Name	Description
var	contract-owner	Address of the contract deployer/owner
var	next-habit-id	Incremental ID counter for new habits
map	habits	Stores habit details (owner, description, stake, logs, duration, status)
map	daily-logs	Records daily logging activity per habit
map	user-balances	Tracks total amount staked per user
⚙️ Public Functions
Function	Description
create-habit	Creates a new habit and locks STX tokens in escrow.
log-habit	Records a daily log entry for a specific habit.
claim-refund	Allows user to withdraw their staked STX if goals are met.
claim-forfeit	Enables the contract owner to claim forfeited stakes after the habit period.
🔍 Read-Only Functions
Function	Description
get-habit	Retrieves a habit’s details.
get-daily-log	Checks if a log exists for a habit on a given day.
get-user-balance	Returns the user’s total staked amount.
get-current-day	Calculates how many days have passed since the habit started.
get-contract-owner	Returns the contract owner’s principal.
🚨 Error Codes
Code	Constant	Meaning
u100	ERR_NOT_AUTHORIZED	Unauthorized caller
u101	ERR_INVALID_AMOUNT	Invalid or zero amount provided
u102	ERR_HABIT_NOT_FOUND	Habit not found or inactive
u103	ERR_ALREADY_LOGGED	Habit already logged for the current day
u104	ERR_INSUFFICIENT_BALANCE	Insufficient logs or stake
u105	ERR_TOO_EARLY	Cannot perform action yet (habit still active)
🧠 Logic Flow Summary

User stakes STX → create-habit

User logs daily → log-habit

After duration:

If logs ≥ required → claim-refund

If logs < required → owner can claim-forfeit

🔒 Security Notes

Only the habit owner can log or claim a refund.

Only the contract owner can claim forfeited stakes.

Habits cannot be reused or altered once inactive.

Block height-based timing prevents manipulation of logs.

🧪 Testing Suggestions

Test the following scenarios:

Successful habit creation and refund.

Daily logging and prevention of double logging.

Refund after meeting log requirements.

Forfeit claim by contract owner when user fails.

Handling of invalid IDs, zero amounts, and unauthorized access.

🧱 Deployment

Deploy using Clarinet
.

Ensure you set the contract owner as the deployer.

Interact with the contract using Clarinet console or Stacks wallet-integrated frontend.

💡 Example Use Case

A user wants to build a “Daily Workout” habit for 10 days, staking 50 STX.
They log each day’s activity using log-habit.
After 10 days, if they’ve logged 10 times, they call claim-refund to recover their 50 STX.

🧾 License

MIT License – Open for community use and improvement.