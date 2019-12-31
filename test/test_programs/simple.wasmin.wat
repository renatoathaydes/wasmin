(module

  (export "add-number" (func $add-number))
  (global $number i64 (i64.const 10))
  (global $large_number (export "large_number") (mut i64) (i64.const 0))
  (func $add-number (param $n i64) (result i64)
    (i64.add
      (global.get $number)
      (local.get $n)
    )
  )
  (func $__wasmin__start__
    (global.set $large_number
      (call $add-number
        (i64.const 33)
      )
    )
  )
  (start $__wasmin__start__)
)
