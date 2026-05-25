# Sparrow -> Owl

## `#649` remove all `lua.*` tables and macros
Except for `lua.require`

**Deprecated**

```
lua.math.floor(5.5)
lua.math.random()
lua.string.sub(abc, 1, 2)
```

**Remplacement**
```
$5.5.floor()
let random = $Random()
$random()
$("abc").sub(1, 2)
```

_See Math, Random, Number and String tables for all methods_

## `#185` `raise` cannot anymore be an identifier

## `#645` `Table.append` behavior change

Do `$Table.append($t, $Table(a, b))` instead of `$Table.append($t, a, b)`

## `#171` getindex raise indexerror

User-defined `getindex` metamacro that returns `empty` will raise an index error.

## `#772` Table.removeKey should raise an error if key is missing

Check if the key exists before calling `Table.removeKey`. 

## `#801` context rework

*	Context are now full variables instead of keys.
*	Write `with ($x: 5)` instead of `with x: 5`.
*	Write `with ($plume.locale: fr)` instead of `with locale: fr`
*	Write `let x = $Context();...;$x()` instead of `let context x;...;$x`
*	`use #context` only works for `plume.*` context variables.
