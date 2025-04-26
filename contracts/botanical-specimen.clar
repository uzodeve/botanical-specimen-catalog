;; Botanical Specimen Catalog Smart Contract
;; Provides a comprehensive system for indexing, managing and sharing botanical specimens 
;; with appropriate access controls for scientific collaboration



;; System Constants and Error Codes
(define-constant SYSTEM_ADMINISTRATOR tx-sender)
(define-constant ERR_UNAUTHORIZED_ACTION (err u300))
(define-constant ERR_SPECIMEN_NOT_FOUND (err u301))
(define-constant ERR_SPECIMEN_DUPLICATE_ENTRY (err u302))
(define-constant ERR_INVALID_SPECIMEN_TITLE (err u303))
(define-constant ERR_INVALID_SPECIMEN_SIZE (err u304))
(define-constant ERR_ACCESS_RESTRICTED (err u305))

;; Global Counter Management
(define-data-var specimen-index uint u0)

;; Primary Data Structure for Specimen Records
(define-map botanical-specimens
  { specimen-id: uint }
  {
    specimen-title: (string-ascii 80),
    specimen-collector: principal,
    specimen-size: uint,
    collection-block: uint,
    specimen-description: (string-ascii 256),
    classification-labels: (list 8 (string-ascii 40))
  }
)

;; Access Control Mapping
(define-map specimen-access-rights
  { specimen-id: uint, researcher: principal }
  { can-examine: bool }
)

;; Helper Functions for Validation and State Checking

;; Checks if specimen record exists in database
(define-private (specimen-record-exists (specimen-id uint))
  (is-some (map-get? botanical-specimens { specimen-id: specimen-id }))
)

;; Validates classification labels format and constraints
(define-private (are-classification-labels-valid (labels (list 8 (string-ascii 40))))
  (and
    (> (len labels) u0)
    (<= (len labels) u8)
    (is-eq (len (filter is-label-valid labels)) (len labels))
  )
)

;; Verifies if current user is the original collector of specimen
(define-private (is-specimen-collector (specimen-id uint) (collector principal))
  (match (map-get? botanical-specimens { specimen-id: specimen-id })
    specimen-data (is-eq (get specimen-collector specimen-data) collector)
    false
  )
)

;; Retrieves the size measurement of a specific specimen
(define-private (get-specimen-size (specimen-id uint))
  (default-to u0 
    (get specimen-size 
      (map-get? botanical-specimens { specimen-id: specimen-id })
    )
  )
)

;; Checks if a classification label meets formatting requirements
(define-private (is-label-valid (label (string-ascii 40)))
  (and 
    (> (len label) u0)
    (< (len label) u41)
  )
)

;; Core Specimen Management Functions

;; Generates UI-friendly view of specimen information for display
(define-public (display-specimen-information (specimen-id uint))
  (let
    (
      (specimen-data (unwrap! (map-get? botanical-specimens { specimen-id: specimen-id }) ERR_SPECIMEN_NOT_FOUND))
    )
    ;; Return formatted specimen information suitable for user interface
    (ok {
      page-title: "Specimen Information",
      specimen-title: (get specimen-title specimen-data),
      specimen-collector: (get specimen-collector specimen-data),
      specimen-description: (get specimen-description specimen-data),
      classification-labels: (get classification-labels specimen-data)
    })
  )
)

;; Registers a new botanical specimen in the catalog with all metadata
(define-public (register-specimen (title (string-ascii 80)) (size uint) (description (string-ascii 256)) (labels (list 8 (string-ascii 40))))
  (let
    (
      (specimen-id (+ (var-get specimen-index) u1))
    )
    ;; Input validation checks
    (asserts! (> (len title) u0) ERR_INVALID_SPECIMEN_TITLE)
    (asserts! (< (len title) u81) ERR_INVALID_SPECIMEN_TITLE)
    (asserts! (> size u0) ERR_INVALID_SPECIMEN_SIZE)
    (asserts! (< size u2000000000) ERR_INVALID_SPECIMEN_SIZE)
    (asserts! (> (len description) u0) ERR_INVALID_SPECIMEN_TITLE)
    (asserts! (< (len description) u257) ERR_INVALID_SPECIMEN_TITLE)
    (asserts! (are-classification-labels-valid labels) ERR_INVALID_SPECIMEN_TITLE)

    ;; Record specimen data in the main catalog
    (map-insert botanical-specimens
      { specimen-id: specimen-id }
      {
        specimen-title: title,
        specimen-collector: tx-sender,
        specimen-size: size,
        collection-block: block-height,
        specimen-description: description,
        classification-labels: labels
      }
    )

    ;; Grant specimen access to collector automatically
    (map-insert specimen-access-rights
      { specimen-id: specimen-id, researcher: tx-sender }
      { can-examine: true }
    )

    ;; Update global specimen counter
    (var-set specimen-index specimen-id)
    (ok specimen-id)
  )
)

;; Alternative implementation with identical functionality but clearer organization
(define-public (catalog-new-specimen (title (string-ascii 80)) (size uint) (description (string-ascii 256)) (labels (list 8 (string-ascii 40))))
  (let
    (
      (specimen-id (+ (var-get specimen-index) u1))
    )
    ;; Parameter validation
    (asserts! (> (len title) u0) ERR_INVALID_SPECIMEN_TITLE)
    (asserts! (< (len title) u81) ERR_INVALID_SPECIMEN_TITLE)
    (asserts! (> size u0) ERR_INVALID_SPECIMEN_SIZE)
    (asserts! (< size u2000000000) ERR_INVALID_SPECIMEN_SIZE)
    (asserts! (> (len description) u0) ERR_INVALID_SPECIMEN_TITLE)
    (asserts! (< (len description) u257) ERR_INVALID_SPECIMEN_TITLE)
    (asserts! (are-classification-labels-valid labels) ERR_INVALID_SPECIMEN_TITLE)

    ;; Persist specimen record to blockchain
    (map-insert botanical-specimens
      { specimen-id: specimen-id }
      {
        specimen-title: title,
        specimen-collector: tx-sender,
        specimen-size: size,
        collection-block: block-height,
        specimen-description: description,
        classification-labels: labels
      }
    )

    ;; Configure initial access permissions
    (map-insert specimen-access-rights
      { specimen-id: specimen-id, researcher: tx-sender }
      { can-examine: true }
    )

    ;; Update specimen counter
    (var-set specimen-index specimen-id)
    (ok specimen-id)
  )
)

;; Updates an existing specimen record with new information
(define-public (update-specimen-record (specimen-id uint) (revised-title (string-ascii 80)) (revised-size uint) (revised-description (string-ascii 256)) (revised-labels (list 8 (string-ascii 40))))
  (let
    (
      (specimen-data (unwrap! (map-get? botanical-specimens { specimen-id: specimen-id }) ERR_SPECIMEN_NOT_FOUND))
    )
    ;; Verify specimen exists and user has appropriate permissions
    (asserts! (specimen-record-exists specimen-id) ERR_SPECIMEN_NOT_FOUND)
    (asserts! (is-eq (get specimen-collector specimen-data) tx-sender) ERR_ACCESS_RESTRICTED)

    ;; Validate updated information
    (asserts! (> (len revised-title) u0) ERR_INVALID_SPECIMEN_TITLE)
    (asserts! (< (len revised-title) u81) ERR_INVALID_SPECIMEN_TITLE)
    (asserts! (> revised-size u0) ERR_INVALID_SPECIMEN_SIZE)
    (asserts! (< revised-size u2000000000) ERR_INVALID_SPECIMEN_SIZE)
    (asserts! (> (len revised-description) u0) ERR_INVALID_SPECIMEN_TITLE)
    (asserts! (< (len revised-description) u257) ERR_INVALID_SPECIMEN_TITLE)
    (asserts! (are-classification-labels-valid revised-labels) ERR_INVALID_SPECIMEN_TITLE)

    ;; Update specimen record with new information
    (map-set botanical-specimens
      { specimen-id: specimen-id }
      (merge specimen-data { 
        specimen-title: revised-title, 
        specimen-size: revised-size, 
        specimen-description: revised-description, 
        classification-labels: revised-labels 
      })
    )
    (ok true)
  )
)

;; Removes a specimen from the botanical catalog
(define-public (withdraw-specimen (specimen-id uint))
  (let
    (
      (specimen-data (unwrap! (map-get? botanical-specimens { specimen-id: specimen-id }) ERR_SPECIMEN_NOT_FOUND))
    )
    ;; Verify specimen exists and user has permission to remove
    (asserts! (specimen-record-exists specimen-id) ERR_SPECIMEN_NOT_FOUND)
    (asserts! (is-eq (get specimen-collector specimen-data) tx-sender) ERR_ACCESS_RESTRICTED)

    ;; Remove specimen from catalog completely
    (map-delete botanical-specimens { specimen-id: specimen-id })
    (ok true)
  )
)

;; Optimized Specimen Information Retrieval Functions

;; Retrieves essential specimen data with minimized computational cost
(define-public (retrieve-specimen-basic (specimen-id uint))
  (let
    (
      (specimen-data (unwrap! (map-get? botanical-specimens { specimen-id: specimen-id }) ERR_SPECIMEN_NOT_FOUND))
    )
    ;; Return only fundamental specimen details to optimize gas usage
    (ok {
      specimen-title: (get specimen-title specimen-data),
      specimen-collector: (get specimen-collector specimen-data),
      specimen-size: (get specimen-size specimen-data)
    })
  )
)
;; This function provides streamlined specimen information for efficient blockchain queries

;; Creates comprehensive specimen data structure for UI presentation
(define-public (prepare-specimen-display (specimen-id uint))
  (let
    (
      (specimen-data (unwrap! (map-get? botanical-specimens { specimen-id: specimen-id }) ERR_SPECIMEN_NOT_FOUND))
    )
    ;; Assemble complete specimen information package for display
    (ok {
      title: (get specimen-title specimen-data),
      collector: (get specimen-collector specimen-data),
      size: (get specimen-size specimen-data),
      description: (get specimen-description specimen-data),
      labels: (get classification-labels specimen-data)
    })
  )
)

;; Ultra-efficient specimen identifier retrieval function
(define-public (retrieve-specimen-minimal (specimen-id uint))
  (let
    (
      (specimen-data (unwrap! (map-get? botanical-specimens { specimen-id: specimen-id }) ERR_SPECIMEN_NOT_FOUND))
    )
    ;; Return absolute minimum necessary identification information
    (ok {
      specimen-title: (get specimen-title specimen-data),
      specimen-collector: (get specimen-collector specimen-data)
    })
  )
)
;; Provides bare essential specimen information for highest efficiency lookups

;; Retrieves only the specimen's scientific description
(define-public (retrieve-specimen-description (specimen-id uint))
  (let
    (
      (specimen-data (unwrap! (map-get? botanical-specimens { specimen-id: specimen-id }) ERR_SPECIMEN_NOT_FOUND))
    )
    (ok (get specimen-description specimen-data))
  )
)

;; Validation utility for testing specimen submission parameters
(define-public (verify-specimen-parameters (title (string-ascii 80)) (size uint) (description (string-ascii 256)) (labels (list 8 (string-ascii 40))))
  (begin
    ;; Validate specimen title format
    (asserts! (> (len title) u0) ERR_INVALID_SPECIMEN_TITLE)
    (asserts! (< (len title) u81) ERR_INVALID_SPECIMEN_TITLE)
    ;; Validate specimen size measurements
    (asserts! (> size u0) ERR_INVALID_SPECIMEN_SIZE)
    (asserts! (< size u2000000000) ERR_INVALID_SPECIMEN_SIZE)
    ;; Validate specimen description length
    (asserts! (> (len description) u0) ERR_INVALID_SPECIMEN_TITLE)
    (asserts! (< (len description) u257) ERR_INVALID_SPECIMEN_TITLE)
    ;; Validate classification labels format and content
    (asserts! (are-classification-labels-valid labels) ERR_INVALID_SPECIMEN_TITLE)
    (ok true)
  )
)

