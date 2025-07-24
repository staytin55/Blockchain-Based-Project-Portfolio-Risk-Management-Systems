;; Mitigation Planning Contract
;; Plans and tracks risk mitigation strategies

;; Constants
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_NOT_FOUND (err u401))
(define-constant ERR_INVALID_INPUT (err u402))
(define-constant ERR_ALREADY_EXISTS (err u403))

;; Data Variables
(define-data-var next-plan-id uint u1)
(define-data-var next-action-id uint u1)

;; Data Maps
(define-map mitigation-plans
  { plan-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 400),
    target-risk-id: uint,
    owner: principal,
    created-at: uint,
    target-completion: uint,
    status: (string-ascii 20),
    priority: uint,
    budget-allocated: uint
  }
)

(define-map mitigation-actions
  { action-id: uint }
  {
    plan-id: uint,
    title: (string-ascii 80),
    description: (string-ascii 300),
    assigned-to: principal,
    due-date: uint,
    status: (string-ascii 20),
    progress: uint,
    cost-estimate: uint
  }
)

(define-map plan-resources
  { plan-id: uint, resource-type: (string-ascii 30) }
  {
    quantity: uint,
    allocated: uint,
    cost-per-unit: uint
  }
)

;; Public Functions

;; Create a mitigation plan
(define-public (create-mitigation-plan
  (title (string-ascii 100))
  (description (string-ascii 400))
  (target-risk-id uint)
  (target-completion uint)
  (priority uint)
  (budget-allocated uint)
)
  (let
    (
      (plan-id (var-get next-plan-id))
    )
    (asserts! (> (len title) u0) ERR_INVALID_INPUT)
    (asserts! (> target-completion block-height) ERR_INVALID_INPUT)
    (asserts! (<= priority u5) ERR_INVALID_INPUT)

    (map-set mitigation-plans
      { plan-id: plan-id }
      {
        title: title,
        description: description,
        target-risk-id: target-risk-id,
        owner: tx-sender,
        created-at: block-height,
        target-completion: target-completion,
        status: "planning",
        priority: priority,
        budget-allocated: budget-allocated
      }
    )

    (var-set next-plan-id (+ plan-id u1))
    (ok plan-id)
  )
)

;; Add mitigation action
(define-public (add-mitigation-action
  (plan-id uint)
  (title (string-ascii 80))
  (description (string-ascii 300))
  (assigned-to principal)
  (due-date uint)
  (cost-estimate uint)
)
  (let
    (
      (action-id (var-get next-action-id))
    )
    (asserts! (is-some (map-get? mitigation-plans { plan-id: plan-id })) ERR_NOT_FOUND)
    (asserts! (> (len title) u0) ERR_INVALID_INPUT)
    (asserts! (> due-date block-height) ERR_INVALID_INPUT)

    (map-set mitigation-actions
      { action-id: action-id }
      {
        plan-id: plan-id,
        title: title,
        description: description,
        assigned-to: assigned-to,
        due-date: due-date,
        status: "pending",
        progress: u0,
        cost-estimate: cost-estimate
      }
    )

    (var-set next-action-id (+ action-id u1))
    (ok action-id)
  )
)

;; Update action progress
(define-public (update-action-progress (action-id uint) (progress uint))
  (begin
    (asserts! (<= progress u100) ERR_INVALID_INPUT)
    (match (map-get? mitigation-actions { action-id: action-id })
      action-data
      (if (is-eq (get assigned-to action-data) tx-sender)
        (let
          (
            (new-status (if (>= progress u100) "completed" "in-progress"))
          )
          (map-set mitigation-actions
            { action-id: action-id }
            (merge action-data {
              progress: progress,
              status: new-status
            })
          )
          (ok true)
        )
        ERR_UNAUTHORIZED
      )
      ERR_NOT_FOUND
    )
  )
)

;; Allocate resources to plan
(define-public (allocate-resources
  (plan-id uint)
  (resource-type (string-ascii 30))
  (quantity uint)
  (cost-per-unit uint)
)
  (match (map-get? mitigation-plans { plan-id: plan-id })
    plan-data
    (if (is-eq (get owner plan-data) tx-sender)
      (begin
        (map-set plan-resources
          { plan-id: plan-id, resource-type: resource-type }
          {
            quantity: quantity,
            allocated: u0,
            cost-per-unit: cost-per-unit
          }
        )
        (ok true)
      )
      ERR_UNAUTHORIZED
    )
    ERR_NOT_FOUND
  )
)

;; Update plan status
(define-public (update-plan-status (plan-id uint) (new-status (string-ascii 20)))
  (match (map-get? mitigation-plans { plan-id: plan-id })
    plan-data
    (if (is-eq (get owner plan-data) tx-sender)
      (begin
        (map-set mitigation-plans
          { plan-id: plan-id }
          (merge plan-data { status: new-status })
        )
        (ok true)
      )
      ERR_UNAUTHORIZED
    )
    ERR_NOT_FOUND
  )
)

;; Read-only Functions

;; Get mitigation plan
(define-read-only (get-mitigation-plan (plan-id uint))
  (map-get? mitigation-plans { plan-id: plan-id })
)

;; Get mitigation action
(define-read-only (get-mitigation-action (action-id uint))
  (map-get? mitigation-actions { action-id: action-id })
)

;; Get plan resources
(define-read-only (get-plan-resources (plan-id uint) (resource-type (string-ascii 30)))
  (map-get? plan-resources { plan-id: plan-id, resource-type: resource-type })
)

;; Calculate plan completion percentage
(define-read-only (calculate-plan-completion (plan-id uint))
  ;; This would require iterating through actions, simplified for demo
  (some u0)
)

;; Check if plan is overdue
(define-read-only (is-plan-overdue (plan-id uint))
  (match (map-get? mitigation-plans { plan-id: plan-id })
    plan-data
    (and
      (< (get target-completion plan-data) block-height)
      (not (is-eq (get status plan-data) "completed"))
    )
    false
  )
)
