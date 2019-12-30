(module

  (export "add-number" (func $add-number))
  (global $number i64 (i64.const 10))
  (func $add-number (param $n i64) (result i64)
    (i64.add
      (global.get $number)
      (local.get $n)
    )
  )
)
