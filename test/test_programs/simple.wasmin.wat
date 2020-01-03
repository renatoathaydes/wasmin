(module

  (export "add-number" (func $add-number))
  (global $number i32 (i32.const 10))
  (global $large_number (export "large_number") (mut i32) (i32.const 0))
  (func $add-number (param $n i32) (result i32)
    (i32.add
      (global.get $number)
      (local.get $n)
    )
  )
  (func $__wasmin__start__
    (global.set $large_number
      (call $add-number
        (i32.const 33)
      )
    )
  )
  (start $__wasmin__start__)
)
