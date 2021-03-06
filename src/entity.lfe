(defmodule entity
  (behaviour supervisor)
  ;; API
  (export ;(new 2)
          ;(move 2)
          ;(rotate 2)
          all)
  ;; gen_server callbacks
  (export (init 1)))

(include-lib "src/data.lfe")


;;;===================================================================
;;; API
;;;===================================================================

(defun start-link (pos conf)
  (let (((tuple 'ok entity) (supervisor:start_link (MODULE) '())))
    (progn
      (lists:foreach (lambda (comp) (add-component entity comp)) conf)
      (set-pos entity pos)
      (entity-server:add entity)
      entity)))


(defun add-component (entity comp)
  (let ((name (element 1 comp)))
    (supervisor:start_child entity (map 'id name
                                        'start (tuple name 'start-link (list (list entity comp)))))))

(defun remove-component (entity id)
  (progn
    (supervisor:terminate_child entity id)
    (supervisor:delete_child entity id)))

(defun get-component (entity id)
  (let* ((children (supervisor:which_children entity))
         ((tuple id pid _ _) (lists:keyfind id 1 children)))
    pid))

(defun cast-component (entity id msg)
  (gen_server:cast (get-component entity id) msg))

(defun call-component (entity id msg)
  (gen_server:call (get-component entity id) msg))

(defun has-component (entity id)
  (/= (lists:keyfind id 1 (supervisor:which_children entity))
      'false))

; Some often used calls, for convenience.
(defun get-pos (entity)
  (call-component entity 'entity-state 'get-pos))

(defun set-pos (entity pos)
  (cast-component entity 'entity-state (tuple 'set-pos pos)))

(defun take-moves (entity n)
  (call-component entity 'entity-moves (tuple 'take-moves n)))


;;;===================================================================
;;; supervisor callback
;;;===================================================================

(defun init (args)
  (let ((restart-strategy (map
                           'strategy 'one_for_one
                           'intensity 10
                           'period 10)))
    (tuple 'ok (tuple restart-strategy '()))))

(defun handle_call
  (('get-state from (tuple state conf))
    (tuple 'reply state (tuple state conf)))
  (('get-conf from (tuple state conf))
    (tuple 'reply conf (tuple state conf))))

(defun handle_cast
  (((tuple 'move dir) (tuple state conf))
   (let ((new-pos (move-in-dir (entity-state-pos state) (entity-state-rot state) dir)))
     (progn (entity-server:update state)
            (tuple 'noreply (tuple (set-entity-state-pos state new-pos)
                                   conf)))))
  (((tuple 'rotate dir) (tuple state conf))
   (tuple 'noreply (tuple (set-entity-state-rot state (+ dir (entity-state-rot state)))
                          conf))))

(defun handle_info (info state)
  (tuple 'noreply state))

(defun terminate (reason state)
  'ok)

(defun code_change (old-version state extra)
  (tuple 'ok state))


;;;===================================================================
;;; Private
;;;===================================================================

(defun rot-to-vec
  ((0) #(0 1))
  ((1) #(1 1))
  ((2) #(1 0))
  ((3) #(1 -1))
  ((4) #(0 -1))
  ((5) #(-1 -1))
  ((6) #(-1 0))
  ((7) #(-1 1)))

(defun move-in-dir (pos rot dir)
  (vec-add pos (rot-to-vec (rem (+ rot dir) 8))))

(defun vec-add
  (((tuple x1 y1) (tuple x2 y2))
   (tuple (+ x1 x2) (+ y1 y2))))


;;;===================================================================
;;; Entities
;;;===================================================================

(defun stalker ()
  (list (make-entity-state
         name "Stalker"
         icon #\@)
        (make-entity-moves)))

; (defun dog ()
;   (make-entity-conf
;    name "Blind Dog"
;    icon #\d
;    max-hp 40
;    actions '(walk run attack)
;    more (list(make-alive
;               speed-walk 75
;               speed-run 200
;               attack-min 0
;               attack-max 10))))

; (defun weapon-knife ()
;   (make-entity-conf
;    name "Knife"
;    icon #\t
;    max-hp 10000
;    actions '(pick-up wield)
;    more (list (make-weapon melee-damage 40)
;               (make-weapon-upgrade melee-damage 40))))
; 
; (defun weapon-ak74 ()
;   (make-entity-conf
;    name "AK-74"
;    icon #\/
;    max-hp 1000
;    actions '(pick-up wield fire reload-weapon upgrade-weapon)
;    more (list (make-weapon
;                ammo '("5.45×39mm")
;                mags '("AK-74 Magazine")
;                accuracy 1.0
;                fire-modes '(auto one)
;                upgrades '("Knife" "1P29")))))
; 
; (defun mag-ak74-mag ()
;   (make-entity-conf
;    name "AK-74 Magazine"
;    icon #\=
;    max-hp 1000
;    actions '(pick-up reload-mag)
;    more (list (make-mag capacity 30))))
; 
; (defun bullet-5.45x39mm ()
;   (make-entity-conf
;    name "5.45×39mm"
;    icon #\a
;    max-hp 20
;    actions '(pick-up)
;    more (list (make-ammo damage 100))))
; 
; (defun scope-1P29 ()
;   (make-entity-conf
;    name "1P29"
;    icon #\o
;    max-hp 50
;    actions '(pick-up)
;    more (list (make-weapon-upgrade accuracy 1.0))))