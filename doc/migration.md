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