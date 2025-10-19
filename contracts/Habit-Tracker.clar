;; Habit Tracker with Escrow Contract
;; Users stake STX tokens and earn them back by logging habits consistently

;; Constants
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_HABIT_NOT_FOUND (err u102))
(define-constant ERR_ALREADY_LOGGED (err u103))
(define-constant ERR_INSUFFICIENT_BALANCE (err u104))
(define-constant ERR_TOO_EARLY (err u105))

;; Data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var next-habit-id uint u1)

;; Data maps
(define-map habits
    { habit-id: uint }
    {
        owner: principal,
        description: (string-ascii 100),
        stake-amount: uint,
        required-logs: uint,
        current-logs: uint,
        start-block: uint,
        end-block: uint,
        is-active: bool
    }
)

(define-map daily-logs
    { habit-id: uint, day: uint }
    { logged: bool, block-height: uint }
)

(define-map user-balances
    { user: principal }
    { staked: uint }
)

;; Private functions
(define-private (is-contract-owner)
    (is-eq tx-sender (var-get contract-owner))
)

(define-private (get-day-from-start (start-block uint) (current-block uint))
    (/ (- current-block start-block) u144)
)

;; Public functions

;; Create a new habit with escrow
(define-public (create-habit (description (string-ascii 100)) (stake-amount uint) (required-logs uint) (duration-days uint))
    (let
        (
            (habit-id (var-get next-habit-id))
            (current-block block-height)
            (start-block current-block)
            (end-block (+ current-block (* duration-days u144)))
        )
        (asserts! (> stake-amount u0) ERR_INVALID_AMOUNT)
        (asserts! (> required-logs u0) ERR_INVALID_AMOUNT)
        (asserts! (> duration-days u0) ERR_INVALID_AMOUNT)
        (asserts! (> (len description) u0) ERR_INVALID_AMOUNT)

        ;; Transfer stake to contract
        (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))

        ;; Create habit record
        (map-set habits
            { habit-id: habit-id }
            {
                owner: tx-sender,
                description: description,
                stake-amount: stake-amount,
                required-logs: required-logs,
                current-logs: u0,
                start-block: start-block,
                end-block: end-block,
                is-active: true
            }
        )

        ;; Update user balance
        (map-set user-balances
            { user: tx-sender }
            { staked: (+ (get staked (default-to { staked: u0 } (map-get? user-balances { user: tx-sender }))) stake-amount) }
        )

        ;; Increment habit ID
        (var-set next-habit-id (+ habit-id u1))

        (ok habit-id)
    )
)

;; Log a habit for today
(define-public (log-habit (habit-id uint))
    (let
        (
            (habit-data (unwrap! (map-get? habits { habit-id: habit-id }) ERR_HABIT_NOT_FOUND))
            (current-block block-height)
            (current-day (get-day-from-start (get start-block habit-data) current-block))
        )
        (asserts! (> habit-id u0) ERR_INVALID_AMOUNT)
        (asserts! (is-eq tx-sender (get owner habit-data)) ERR_NOT_AUTHORIZED)
        (asserts! (get is-active habit-data) ERR_HABIT_NOT_FOUND)
        (asserts! (<= current-block (get end-block habit-data)) ERR_TOO_EARLY)
        (asserts! (>= current-day u0) ERR_INVALID_AMOUNT)
        (asserts! (is-none (map-get? daily-logs { habit-id: habit-id, day: current-day })) ERR_ALREADY_LOGGED)

        ;; Record the log
        (map-set daily-logs
            { habit-id: habit-id, day: current-day }
            { logged: true, block-height: current-block }
        )

        ;; Update habit log count
        (map-set habits
            { habit-id: habit-id }
            (merge habit-data { current-logs: (+ (get current-logs habit-data) u1) })
        )

        (ok true)
    )
)

;; Claim refund if habit goals are met
(define-public (claim-refund (habit-id uint))
    (let
        (
            (habit-data (unwrap! (map-get? habits { habit-id: habit-id }) ERR_HABIT_NOT_FOUND))
            (user-balance (default-to { staked: u0 } (map-get? user-balances { user: tx-sender })))
            (current-block block-height)
        )
        (asserts! (> habit-id u0) ERR_INVALID_AMOUNT)
        (asserts! (is-eq tx-sender (get owner habit-data)) ERR_NOT_AUTHORIZED)
        (asserts! (get is-active habit-data) ERR_HABIT_NOT_FOUND)
        (asserts! (> current-block (get end-block habit-data)) ERR_TOO_EARLY)
        (asserts! (>= (get current-logs habit-data) (get required-logs habit-data)) ERR_INSUFFICIENT_BALANCE)

        ;; Mark habit as inactive
        (map-set habits
            { habit-id: habit-id }
            (merge habit-data { is-active: false })
        )

        ;; Update user balance
        (map-set user-balances
            { user: tx-sender }
            { staked: (- (get staked user-balance) (get stake-amount habit-data)) }
        )

        ;; Transfer stake back to user
        (try! (as-contract (stx-transfer? (get stake-amount habit-data) tx-sender (get owner habit-data))))

        (ok (get stake-amount habit-data))
    )
)

;; Contract owner can claim unclaimed stakes (after habit period ends and goals not met)
(define-public (claim-forfeit (habit-id uint))
    (let
        (
            (habit-data (unwrap! (map-get? habits { habit-id: habit-id }) ERR_HABIT_NOT_FOUND))
            (user-balance (default-to { staked: u0 } (map-get? user-balances { user: (get owner habit-data) })))
            (current-block block-height)
        )
        (asserts! (> habit-id u0) ERR_INVALID_AMOUNT)
        (asserts! (is-contract-owner) ERR_NOT_AUTHORIZED)
        (asserts! (get is-active habit-data) ERR_HABIT_NOT_FOUND)
        (asserts! (> current-block (get end-block habit-data)) ERR_TOO_EARLY)
        (asserts! (< (get current-logs habit-data) (get required-logs habit-data)) ERR_INSUFFICIENT_BALANCE)

        ;; Mark habit as inactive
        (map-set habits
            { habit-id: habit-id }
            (merge habit-data { is-active: false })
        )

        ;; Update user balance
        (map-set user-balances
            { user: (get owner habit-data) }
            { staked: (- (get staked user-balance) (get stake-amount habit-data)) }
        )

        ;; Transfer stake to contract owner
        (try! (as-contract (stx-transfer? (get stake-amount habit-data) tx-sender (var-get contract-owner))))

        (ok (get stake-amount habit-data))
    )
)

;; Read-only functions

;; Get habit details
(define-read-only (get-habit (habit-id uint))
    (map-get? habits { habit-id: habit-id })
)

;; Check if habit was logged on a specific day
(define-read-only (get-daily-log (habit-id uint) (day uint))
    (map-get? daily-logs { habit-id: habit-id, day: day })
)

;; Get user's staked balance
(define-read-only (get-user-balance (user principal))
    (default-to { staked: u0 } (map-get? user-balances { user: user }))
)

;; Get current day for a habit
(define-read-only (get-current-day (habit-id uint))
    (let ((current-block block-height))
        (match (map-get? habits { habit-id: habit-id })
            habit-data (some (get-day-from-start (get start-block habit-data) current-block))
            none
        )
    )
)

;; Get contract owner
(define-read-only (get-contract-owner)
    (var-get contract-owner)
)