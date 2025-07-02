;; Assessment Coordination Contract
;; Coordinates risk assessments across projects

;; Constants
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_NOT_FOUND (err u301))
(define-constant ERR_INVALID_INPUT (err u302))
(define-constant ERR_ALREADY_EXISTS (err u303))

;; Data Variables
(define-data-var next-assessment-id uint u1)

;; Data Maps
(define-map assessments
  { assessment-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 300),
    assessor: principal,
    target-risk-id: uint,
    scheduled-at: uint,
    completed-at: (optional uint),
    status: (string-ascii 20),
    priority: uint,
    estimated-duration: uint
  }
)

(define-map assessment-results
  { assessment-id: uint }
  {
    findings: (string-ascii 500),
    recommendations: (string-ascii 500),
    risk-level: uint,
    confidence-score: uint,
    next-review-date: uint
  }
)

(define-map assessment-schedule
  { date: uint }
  { assessment-ids: (list 10 uint) }
)

;; Public Functions

;; Schedule a new assessment
(define-public (schedule-assessment
  (title (string-ascii 100))
  (description (string-ascii 300))
  (target-risk-id uint)
  (scheduled-at uint)
  (priority uint)
  (estimated-duration uint)
)
  (let
    (
      (assessment-id (var-get next-assessment-id))
    )
    (asserts! (> (len title) u0) ERR_INVALID_INPUT)
    (asserts! (> scheduled-at block-height) ERR_INVALID_INPUT)
    (asserts! (<= priority u5) ERR_INVALID_INPUT)

    (map-set assessments
      { assessment-id: assessment-id }
      {
        title: title,
        description: description,
        assessor: tx-sender,
        target-risk-id: target-risk-id,
        scheduled-at: scheduled-at,
        completed-at: none,
        status: "scheduled",
        priority: priority,
        estimated-duration: estimated-duration
      }
    )

    (var-set next-assessment-id (+ assessment-id u1))
    (ok assessment-id)
  )
)

;; Start an assessment
(define-public (start-assessment (assessment-id uint))
  (match (map-get? assessments { assessment-id: assessment-id })
    assessment-data
    (if (is-eq (get assessor assessment-data) tx-sender)
      (begin
        (map-set assessments
          { assessment-id: assessment-id }
          (merge assessment-data { status: "in-progress" })
        )
        (ok true)
      )
      ERR_UNAUTHORIZED
    )
    ERR_NOT_FOUND
  )
)

;; Complete an assessment
(define-public (complete-assessment
  (assessment-id uint)
  (findings (string-ascii 500))
  (recommendations (string-ascii 500))
  (risk-level uint)
  (confidence-score uint)
  (next-review-date uint)
)
  (match (map-get? assessments { assessment-id: assessment-id })
    assessment-data
    (if (is-eq (get assessor assessment-data) tx-sender)
      (begin
        (map-set assessments
          { assessment-id: assessment-id }
          (merge assessment-data {
            status: "completed",
            completed-at: (some block-height)
          })
        )
        (map-set assessment-results
          { assessment-id: assessment-id }
          {
            findings: findings,
            recommendations: recommendations,
            risk-level: risk-level,
            confidence-score: confidence-score,
            next-review-date: next-review-date
          }
        )
        (ok true)
      )
      ERR_UNAUTHORIZED
    )
    ERR_NOT_FOUND
  )
)

;; Reschedule an assessment
(define-public (reschedule-assessment (assessment-id uint) (new-scheduled-at uint))
  (begin
    (asserts! (> new-scheduled-at block-height) ERR_INVALID_INPUT)
    (match (map-get? assessments { assessment-id: assessment-id })
      assessment-data
      (if (is-eq (get assessor assessment-data) tx-sender)
        (begin
          (map-set assessments
            { assessment-id: assessment-id }
            (merge assessment-data { scheduled-at: new-scheduled-at })
          )
          (ok true)
        )
        ERR_UNAUTHORIZED
      )
      ERR_NOT_FOUND
    )
  )
)

;; Update assessment priority
(define-public (update-assessment-priority (assessment-id uint) (new-priority uint))
  (begin
    (asserts! (<= new-priority u5) ERR_INVALID_INPUT)
    (match (map-get? assessments { assessment-id: assessment-id })
      assessment-data
      (if (is-eq (get assessor assessment-data) tx-sender)
        (begin
          (map-set assessments
            { assessment-id: assessment-id }
            (merge assessment-data { priority: new-priority })
          )
          (ok true)
        )
        ERR_UNAUTHORIZED
      )
      ERR_NOT_FOUND
    )
  )
)

;; Read-only Functions

;; Get assessment details
(define-read-only (get-assessment (assessment-id uint))
  (map-get? assessments { assessment-id: assessment-id })
)

;; Get assessment results
(define-read-only (get-assessment-results (assessment-id uint))
  (map-get? assessment-results { assessment-id: assessment-id })
)

;; Check if assessment is overdue
(define-read-only (is-assessment-overdue (assessment-id uint))
  (match (map-get? assessments { assessment-id: assessment-id })
    assessment-data
    (and
      (< (get scheduled-at assessment-data) block-height)
      (not (is-eq (get status assessment-data) "completed"))
    )
    false
  )
)

;; Get assessment duration
(define-read-only (get-assessment-duration (assessment-id uint))
  (match (map-get? assessments { assessment-id: assessment-id })
    assessment-data
    (match (get completed-at assessment-data)
      completed-time
      (some (- completed-time (get scheduled-at assessment-data)))
      none
    )
    none
  )
)
