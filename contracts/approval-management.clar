;; Approval Management Contract
;; Manages regulatory approvals and their lifecycle

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u400))
(define-constant err-not-found (err u401))
(define-constant err-unauthorized (err u402))
(define-constant err-already-exists (err u403))

;; Data Variables
(define-data-var next-approval-id uint u1)

;; Data Maps
(define-map approvals
  { approval-id: uint }
  {
    approval-type: (string-ascii 50),
    agency: (string-ascii 50),
    reference-number: (string-ascii 50),
    status: (string-ascii 20),
    granted-at: (optional uint),
    expires-at: (optional uint),
    created-by: principal,
    created-at: uint,
    conditions: (string-ascii 500)
  }
)

(define-map approval-renewals
  { approval-id: uint, renewal-date: uint }
  {
    renewed-by: principal,
    new-expiry: uint,
    renewal-status: (string-ascii 20),
    notes: (string-ascii 300)
  }
)

(define-map approval-conditions
  { approval-id: uint, condition-id: uint }
  {
    condition-text: (string-ascii 300),
    compliance-status: (string-ascii 20),
    due-date: (optional uint),
    completed-at: (optional uint)
  }
)

;; Public Functions
(define-public (create-approval
  (approval-type (string-ascii 50))
  (agency (string-ascii 50))
  (reference-number (string-ascii 50))
  (conditions (string-ascii 500))
)
  (let ((approval-id (var-get next-approval-id)))
    (map-set approvals
      { approval-id: approval-id }
      {
        approval-type: approval-type,
        agency: agency,
        reference-number: reference-number,
        status: "pending",
        granted-at: none,
        expires-at: none,
        created-by: tx-sender,
        created-at: block-height,
        conditions: conditions
      }
    )

    (var-set next-approval-id (+ approval-id u1))
    (ok approval-id)
  )
)

(define-public (grant-approval (approval-id uint) (expires-at uint))
  (let ((approval (unwrap! (map-get? approvals { approval-id: approval-id }) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)

    (map-set approvals
      { approval-id: approval-id }
      (merge approval {
        status: "granted",
        granted-at: (some block-height),
        expires-at: (some expires-at)
      })
    )
    (ok true)
  )
)

(define-public (renew-approval (approval-id uint) (new-expiry uint) (notes (string-ascii 300)))
  (let ((approval (unwrap! (map-get? approvals { approval-id: approval-id }) err-not-found)))
    (asserts! (is-eq (get status approval) "granted") err-unauthorized)

    (map-set approval-renewals
      { approval-id: approval-id, renewal-date: block-height }
      {
        renewed-by: tx-sender,
        new-expiry: new-expiry,
        renewal-status: "pending",
        notes: notes
      }
    )
    (ok true)
  )
)

(define-public (add-condition (approval-id uint) (condition-id uint) (condition-text (string-ascii 300)) (due-date (optional uint)))
  (let ((approval (unwrap! (map-get? approvals { approval-id: approval-id }) err-not-found)))
    (asserts! (or (is-eq tx-sender (get created-by approval)) (is-eq tx-sender contract-owner)) err-unauthorized)

    (map-set approval-conditions
      { approval-id: approval-id, condition-id: condition-id }
      {
        condition-text: condition-text,
        compliance-status: "pending",
        due-date: due-date,
        completed-at: none
      }
    )
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-approval (approval-id uint))
  (map-get? approvals { approval-id: approval-id })
)

(define-read-only (get-renewal (approval-id uint) (renewal-date uint))
  (map-get? approval-renewals { approval-id: approval-id, renewal-date: renewal-date })
)

(define-read-only (get-condition (approval-id uint) (condition-id uint))
  (map-get? approval-conditions { approval-id: approval-id, condition-id: condition-id })
)

(define-read-only (is-approval-expired (approval-id uint))
  (match (map-get? approvals { approval-id: approval-id })
    approval
      (match (get expires-at approval)
        expiry (< expiry block-height)
        false
      )
    false
  )
)
