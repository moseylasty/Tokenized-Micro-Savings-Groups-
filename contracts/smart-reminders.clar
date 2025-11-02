(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_NOT_AUTHORIZED (err u403))
(define-constant ERR_INVALID_AMOUNT (err u401))
(define-constant ERR_NOT_MEMBER (err u402))

(define-constant EARLY_PAYMENT_BONUS u10)
(define-constant ON_TIME_PAYMENT_BONUS u5)
(define-constant LATE_PAYMENT_PENALTY u15)

(define-map roscas uint {
    creator: principal,
    contribution-amount: uint,
    cycle-duration: uint,
    current-cycle: uint,
    is-active: bool,
    created-at: uint
})

(define-map rosca-members {rosca-id: uint, member: principal} {
    is-active: bool,
    joined-at: uint
})

(define-map cycle-contributions {rosca-id: uint, cycle: uint, member: principal} {
    amount: uint,
    contributed-at: uint
})

(define-map member-reminder-prefs {rosca-id: uint, member: principal} {
    wants-early-alerts: bool,
    wants-deadline-alerts: bool,
    preferred-reminder-blocks: uint,
    total-notifications: uint
})

(define-map contribution-analytics {rosca-id: uint, cycle: uint} {
    early-contributors: uint,
    on-time-contributors: uint,
    late-contributors: uint,
    average-contribution-block: uint,
    cycle-health-score: uint
})

(define-read-only (get-rosca (rosca-id uint))
    (map-get? roscas rosca-id)
)

(define-read-only (get-rosca-member (rosca-id uint) (member principal))
    (map-get? rosca-members {rosca-id: rosca-id, member: member})
)

(define-read-only (get-cycle-contribution (rosca-id uint) (cycle uint) (member principal))
    (map-get? cycle-contributions {rosca-id: rosca-id, cycle: cycle, member: member})
)

(define-read-only (get-cycle-deadline-info (rosca-id uint) (cycle uint))
    (let (
        (rosca-data (unwrap! (get-rosca rosca-id) ERR_NOT_FOUND))
        (cycle-duration (get cycle-duration rosca-data))
        (cycle-start (+ (get created-at rosca-data) (* (- cycle u1) cycle-duration)))
    )
        (ok {
            early-deadline: (+ cycle-start (/ cycle-duration u2)),
            standard-deadline: (+ cycle-start cycle-duration),
            late-cutoff: (+ cycle-start (* cycle-duration u2)),
            cycle-start: cycle-start,
            blocks-remaining: (if (> (+ cycle-start cycle-duration) stacks-block-height)
                (- (+ cycle-start cycle-duration) stacks-block-height)
                u0
            )
        })
    )
)

(define-public (setup-reminder-preferences (rosca-id uint) (early-alerts bool) (deadline-alerts bool) (reminder-blocks uint))
    (let (
        (rosca-data (unwrap! (get-rosca rosca-id) ERR_NOT_FOUND))
        (member-data (map-get? rosca-members {rosca-id: rosca-id, member: tx-sender}))
    )
        (asserts! (is-some member-data) ERR_NOT_MEMBER)
        (asserts! (get is-active (unwrap-panic member-data)) ERR_NOT_MEMBER)
        (asserts! (<= reminder-blocks u1440) ERR_INVALID_AMOUNT)
        
        (map-set member-reminder-prefs {rosca-id: rosca-id, member: tx-sender} {
            wants-early-alerts: early-alerts,
            wants-deadline-alerts: deadline-alerts,
            preferred-reminder-blocks: reminder-blocks,
            total-notifications: u0
        })
        (ok true)
    )
)

(define-read-only (get-optimal-contribution-window (rosca-id uint) (cycle uint))
    (match (get-cycle-deadline-info rosca-id cycle)
        ok-deadline-info (ok {
            early-bonus-window: {
                start: (get cycle-start ok-deadline-info),
                end: (get early-deadline ok-deadline-info),
                bonus-points: EARLY_PAYMENT_BONUS,
                recommendation: "Contribute now for maximum bonus!"
            },
            standard-window: {
                start: (get early-deadline ok-deadline-info),
                end: (get standard-deadline ok-deadline-info),
                bonus-points: ON_TIME_PAYMENT_BONUS,
                recommendation: "Good time to contribute with standard bonus"
            },
            penalty-risk: {
                start: (get standard-deadline ok-deadline-info),
                penalty-points: LATE_PAYMENT_PENALTY,
                recommendation: "Contribute ASAP to avoid penalty!"
            }
        })
        err-deadline ERR_NOT_FOUND
    )
)

(define-read-only (get-member-contribution-pattern (rosca-id uint) (member principal))
    (let (
        (member-data (get-rosca-member rosca-id member))
        (reminder-prefs (map-get? member-reminder-prefs {rosca-id: rosca-id, member: member}))
    )
        (if (is-some member-data)
            (ok {
                reliability-trend: "consistent",
                preferred-timing: "early",
                notification-engagement: (match reminder-prefs
                    some-prefs (get total-notifications some-prefs)
                    u0
                ),
                recommendation: "Keep up the excellent contribution pattern!"
            })
            ERR_NOT_MEMBER
        )
    )
)
