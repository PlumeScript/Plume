# Owl -> Raven

## Add an error when using non-escaped `$` #900
Escape all non-eval `$`: `\$`

## Leave affect only the current accumulation block instead of the whole macro #916

## Add an error when using non-escaped `$` #900
Escape all non-eval `$`: `\$`

## Leave affect only the current accumulation block instead of the whole macro #916

## Add an error when using undefined files params #981

## String representation rework #650
- Change program output formating behavior #1001
	- `repr` will not be called anymore on `string`, `number`, `bool` and `empty`.
- `repr` now give a more exact representation #1002
- `repr` should print "" instead of empty when possible #1000 _For exemple, in table leafs_
- `repr(table)` shouldn't add `do` in first layer #999

## `import` and `use` results will be cached starting with `raven` release #806
- One cache per parameter combination.
- Using a mutable object as a parameter can lead to unexpected behavior ; a special warning is provided for this #890

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
