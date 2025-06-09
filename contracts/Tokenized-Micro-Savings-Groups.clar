(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_ROSCA_NOT_FOUND (err u102))
(define-constant ERR_ALREADY_MEMBER (err u103))
(define-constant ERR_NOT_MEMBER (err u104))
(define-constant ERR_ROSCA_FULL (err u105))
(define-constant ERR_CONTRIBUTION_PERIOD_ENDED (err u106))
(define-constant ERR_ALREADY_CONTRIBUTED (err u107))
(define-constant ERR_INSUFFICIENT_CONTRIBUTIONS (err u108))
(define-constant ERR_NOT_WINNER (err u109))
(define-constant ERR_ALREADY_CLAIMED (err u110))
(define-constant ERR_ROSCA_ACTIVE (err u111))
(define-constant ERR_INVALID_CYCLE (err u112))

(define-data-var rosca-counter uint u0)
(define-data-var random-seed uint u0)

(define-map roscas uint {
    creator: principal,
    contribution-amount: uint,
    max-members: uint,
    current-members: uint,
    cycle-duration: uint,
    current-cycle: uint,
    total-cycles: uint,
    is-active: bool,
    created-at: uint
})

(define-map rosca-members {rosca-id: uint, member: principal} {
    joined-at: uint,
    total-contributed: uint,
    cycles-won: (list 50 uint),
    is-active: bool
})

(define-map cycle-contributions {rosca-id: uint, cycle: uint, member: principal} {
    amount: uint,
    contributed-at: uint
})

(define-map cycle-winners {rosca-id: uint, cycle: uint} {
    winner: principal,
    amount: uint,
    claimed: bool,
    selected-at: uint
})

(define-map rosca-balances uint uint)

(define-map member-list {rosca-id: uint, index: uint} principal)

(define-read-only (get-rosca (rosca-id uint))
    (map-get? roscas rosca-id)
)

(define-read-only (get-rosca-member (rosca-id uint) (member principal))
    (map-get? rosca-members {rosca-id: rosca-id, member: member})
)

(define-read-only (get-cycle-contribution (rosca-id uint) (cycle uint) (member principal))
    (map-get? cycle-contributions {rosca-id: rosca-id, cycle: cycle, member: member})
)

(define-read-only (get-cycle-winner (rosca-id uint) (cycle uint))
    (map-get? cycle-winners {rosca-id: rosca-id, cycle: cycle})
)

(define-read-only (get-rosca-balance (rosca-id uint))
    (default-to u0 (map-get? rosca-balances rosca-id))
)

(define-read-only (get-total-roscas)
    (var-get rosca-counter)
)

(define-read-only (get-member-by-index (rosca-id uint) (index uint))
    (default-to CONTRACT_OWNER (map-get? member-list {rosca-id: rosca-id, index: index}))
)

(define-public (create-rosca (contribution-amount uint) (max-members uint) (cycle-duration uint))
    (let (
        (rosca-id (+ (var-get rosca-counter) u1))
    )
        (asserts! (> contribution-amount u0) ERR_INVALID_AMOUNT)
        (asserts! (and (>= max-members u2) (<= max-members u50)) ERR_INVALID_AMOUNT)
        (asserts! (> cycle-duration u0) ERR_INVALID_AMOUNT)
        
        (map-set roscas rosca-id {
            creator: tx-sender,
            contribution-amount: contribution-amount,
            max-members: max-members,
            current-members: u1,
            cycle-duration: cycle-duration,
            current-cycle: u1,
            total-cycles: max-members,
            is-active: true,
            created-at: stacks-block-height
        })
        
        (map-set rosca-members {rosca-id: rosca-id, member: tx-sender} {
            joined-at: stacks-block-height,
            total-contributed: u0,
            cycles-won: (list),
            is-active: true
        })
        
        (map-set member-list {rosca-id: rosca-id, index: u0} tx-sender)
        (map-set rosca-balances rosca-id u0)
        (var-set rosca-counter rosca-id)
        (ok rosca-id)
    )
)

(define-public (join-rosca (rosca-id uint))
    (let (
        (rosca-data (unwrap! (get-rosca rosca-id) ERR_ROSCA_NOT_FOUND))
        (existing-member (get-rosca-member rosca-id tx-sender))
        (current-members (get current-members rosca-data))
    )
        (asserts! (is-none existing-member) ERR_ALREADY_MEMBER)
        (asserts! (get is-active rosca-data) ERR_ROSCA_ACTIVE)
        (asserts! (< current-members (get max-members rosca-data)) ERR_ROSCA_FULL)
        
        (map-set rosca-members {rosca-id: rosca-id, member: tx-sender} {
            joined-at: stacks-block-height,
            total-contributed: u0,
            cycles-won: (list),
            is-active: true
        })
        
        (map-set member-list {rosca-id: rosca-id, index: current-members} tx-sender)
        
        (map-set roscas rosca-id (merge rosca-data {
            current-members: (+ current-members u1)
        }))
        
        (ok true)
    )
)

(define-public (contribute (rosca-id uint))
    (let (
        (rosca-data (unwrap! (get-rosca rosca-id) ERR_ROSCA_NOT_FOUND))
        (member-data (unwrap! (get-rosca-member rosca-id tx-sender) ERR_NOT_MEMBER))
        (current-cycle (get current-cycle rosca-data))
        (contribution-amount (get contribution-amount rosca-data))
        (existing-contribution (get-cycle-contribution rosca-id current-cycle tx-sender))
    )
        (asserts! (get is-active rosca-data) ERR_ROSCA_ACTIVE)
        (asserts! (get is-active member-data) ERR_NOT_MEMBER)
        (asserts! (is-none existing-contribution) ERR_ALREADY_CONTRIBUTED)
        
        (try! (stx-transfer? contribution-amount tx-sender (as-contract tx-sender)))
        
        (map-set cycle-contributions {rosca-id: rosca-id, cycle: current-cycle, member: tx-sender} {
            amount: contribution-amount,
            contributed-at: stacks-block-height
        })
        
        (map-set rosca-members {rosca-id: rosca-id, member: tx-sender} (merge member-data {
            total-contributed: (+ (get total-contributed member-data) contribution-amount)
        }))
        
        (map-set rosca-balances rosca-id (+ (get-rosca-balance rosca-id) contribution-amount))
        
        (ok true)
    )
)

(define-public (select-winner (rosca-id uint))
    (begin
        (asserts! (is-some (get-rosca rosca-id)) ERR_ROSCA_NOT_FOUND)
        (asserts! (get is-active (unwrap-panic (get-rosca rosca-id))) ERR_ROSCA_ACTIVE)
        (asserts! (>= (get-rosca-balance rosca-id) (* (get contribution-amount (unwrap-panic (get-rosca rosca-id))) (get current-members (unwrap-panic (get-rosca rosca-id))))) ERR_INSUFFICIENT_CONTRIBUTIONS)
        (asserts! (is-none (get-cycle-winner rosca-id (get current-cycle (unwrap-panic (get-rosca rosca-id))))) ERR_ALREADY_CLAIMED)
        
        (var-set random-seed (+ (var-get random-seed) stacks-block-height))
        
        (map-set cycle-winners {rosca-id: rosca-id, cycle: (get current-cycle (unwrap-panic (get-rosca rosca-id)))} {
            winner: (get-member-by-index rosca-id (mod (var-get random-seed) (get current-members (unwrap-panic (get-rosca rosca-id))))),
            amount: (* (get contribution-amount (unwrap-panic (get-rosca rosca-id))) (get current-members (unwrap-panic (get-rosca rosca-id)))),
            claimed: false,
            selected-at: stacks-block-height
        })
        
        (ok (get-member-by-index rosca-id (mod (var-get random-seed) (get current-members (unwrap-panic (get-rosca rosca-id))))))
    )
)

(define-public (claim-winnings (rosca-id uint) (cycle uint))
    (let (
        (rosca-data (unwrap! (get-rosca rosca-id) ERR_ROSCA_NOT_FOUND))
        (winner-data (unwrap! (get-cycle-winner rosca-id cycle) ERR_INVALID_CYCLE))
        (member-data (unwrap! (get-rosca-member rosca-id tx-sender) ERR_NOT_MEMBER))
    )
        (asserts! (is-eq tx-sender (get winner winner-data)) ERR_NOT_WINNER)
        (asserts! (not (get claimed winner-data)) ERR_ALREADY_CLAIMED)
        
        (try! (as-contract (stx-transfer? (get amount winner-data) tx-sender (get winner winner-data))))
        
        (map-set cycle-winners {rosca-id: rosca-id, cycle: cycle} (merge winner-data {
            claimed: true
        }))
        
        (map-set rosca-balances rosca-id (- (get-rosca-balance rosca-id) (get amount winner-data)))
        
        (let (
            (updated-cycles-won (unwrap-panic (as-max-len? (append (get cycles-won member-data) cycle) u50)))
        )
            (map-set rosca-members {rosca-id: rosca-id, member: tx-sender} (merge member-data {
                cycles-won: updated-cycles-won
            }))
        )
        
        (ok true)
    )
)

(define-public (advance-cycle (rosca-id uint))
    (let (
        (rosca-data (unwrap! (get-rosca rosca-id) ERR_ROSCA_NOT_FOUND))
        (current-cycle (get current-cycle rosca-data))
        (total-cycles (get total-cycles rosca-data))
    )
        (asserts! (is-eq tx-sender (get creator rosca-data)) ERR_NOT_AUTHORIZED)
        (asserts! (get is-active rosca-data) ERR_ROSCA_ACTIVE)
        
        (if (< current-cycle total-cycles)
            (begin
                (map-set roscas rosca-id (merge rosca-data {
                    current-cycle: (+ current-cycle u1)
                }))
                (ok true)
            )
            (begin
                (map-set roscas rosca-id (merge rosca-data {
                    is-active: false
                }))
                (ok false)
            )
        )
    )
)

(define-public (leave-rosca (rosca-id uint))
    (let (
        (rosca-data (unwrap! (get-rosca rosca-id) ERR_ROSCA_NOT_FOUND))
        (member-data (unwrap! (get-rosca-member rosca-id tx-sender) ERR_NOT_MEMBER))
    )
        (asserts! (get is-active member-data) ERR_NOT_MEMBER)
        (asserts! (get is-active rosca-data) ERR_ROSCA_ACTIVE)
        
        (map-set rosca-members {rosca-id: rosca-id, member: tx-sender} (merge member-data {
            is-active: false
        }))
        
        (ok true)
    )
)

(define-public (emergency-withdraw (rosca-id uint))
    (let (
        (rosca-data (unwrap! (get-rosca rosca-id) ERR_ROSCA_NOT_FOUND))
        (balance (get-rosca-balance rosca-id))
    )
        (asserts! (is-eq tx-sender (get creator rosca-data)) ERR_NOT_AUTHORIZED)
        (asserts! (not (get is-active rosca-data)) ERR_ROSCA_ACTIVE)
        (asserts! (> balance u0) ERR_INVALID_AMOUNT)
        
        (try! (as-contract (stx-transfer? balance tx-sender (get creator rosca-data))))
        (map-set rosca-balances rosca-id u0)
        
        (ok balance)
    )
)

(define-read-only (get-rosca-stats (rosca-id uint))
    (match (get-rosca rosca-id)
        rosca-data (ok {
            total-pool: (* (get contribution-amount rosca-data) (get current-members rosca-data)),
            current-balance: (get-rosca-balance rosca-id),
            cycles-remaining: (- (get total-cycles rosca-data) (get current-cycle rosca-data)),
            is-full: (is-eq (get current-members rosca-data) (get max-members rosca-data))
        })
        ERR_ROSCA_NOT_FOUND
    )
)
