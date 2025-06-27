;; Requirement Tracking Contract
;; Tracks regulatory requirements throughout their lifecycle

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-found (err u201))
(define-constant err-unauthorized (err u202))
(define-constant err-invalid-status (err u203))

;; Data Variables
(define-data-var next-requirement-id uint u1)

;; Data Maps
(define-map requirements
  { requirement-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    category: (string-ascii 50),
    priority: (string-ascii 20),
    status: (string-ascii 20),
    created-by: principal,
    created-at: uint,
    due-date: uint,
    completed-at: (optional uint)
  }
)

(define-map requirement-assignments
  { requirement-id: uint, assignee: principal }
  { assigned-at: uint, role: (string-ascii 30) }
)

;; Public Functions
(define-public (create-requirement
  (title (string-ascii 100))
  (description (string-ascii 500))
  (category (string-ascii 50))
  (priority (string-ascii 20))
  (due-date uint)
)
  (let ((requirement-id (var-get next-requirement-id)))
    (map-set requirements
      { requirement-id: requirement-id }
      {
        title: title,
        description: description,
        category: category,
        priority: priority,
        status: "open",
        created-by: tx-sender,
        created-at: block-height,
        due-date: due-date,
        completed-at: none
      }
    )

    (var-set next-requirement-id (+ requirement-id u1))
    (ok requirement-id)
  )
)

(define-public (update-requirement-status (requirement-id uint) (new-status (string-ascii 20)))
  (let ((requirement (unwrap! (map-get? requirements { requirement-id: requirement-id }) err-not-found)))
    (asserts! (or (is-eq tx-sender (get created-by requirement)) (is-eq tx-sender contract-owner)) err-unauthorized)

    (map-set requirements
      { requirement-id: requirement-id }
      (merge requirement {
        status: new-status,
        completed-at: (if (is-eq new-status "completed") (some block-height) (get completed-at requirement))
      })
    )
    (ok true)
  )
)

(define-public (assign-requirement (requirement-id uint) (assignee principal) (role (string-ascii 30)))
  (let ((requirement (unwrap! (map-get? requirements { requirement-id: requirement-id }) err-not-found)))
    (asserts! (or (is-eq tx-sender (get created-by requirement)) (is-eq tx-sender contract-owner)) err-unauthorized)

    (map-set requirement-assignments
      { requirement-id: requirement-id, assignee: assignee }
      { assigned-at: block-height, role: role }
    )
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-requirement (requirement-id uint))
  (map-get? requirements { requirement-id: requirement-id })
)

(define-read-only (get-assignment (requirement-id uint) (assignee principal))
  (map-get? requirement-assignments { requirement-id: requirement-id, assignee: assignee })
)

(define-read-only (is-overdue (requirement-id uint))
  (match (map-get? requirements { requirement-id: requirement-id })
    requirement (and (not (is-eq (get status requirement) "completed")) (< (get due-date requirement) block-height))
    false
  )
)
