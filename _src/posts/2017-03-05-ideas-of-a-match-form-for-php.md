    Title: Ideas of a match form for PHP
    Date: 2017-03-05T14:25:10
    Tags: php,racket

<p class="lead"> This post explore the idea of how would look like if pattern matching would be
added to PHP.</p>

<br/>

And by pattern matching i actually mean
racket's
[match](https://docs.racket-lang.org/reference/match.html?q=match#%28form._%28%28lib._racket%2Fmatch..rkt%29._match%29%29) form.

<!-- more -->

## An example

```php
<?php

class Maison {
    public $voiture = 1;
    public $camion = 2;
    public function moreVoiture($value) { return $this->voiture + $value; }
}


match($someExpr) {
    case 12:
        var_dump(12);
        break;
    case "toto": 
        var_dump("toto");
        break;
    case (int) as $someVar:
        var_dump($someVar);
        break;
    case instanceof Maison(->voiture => 1, ->camion => (int) as $r) as $result:
        var_dump($result);
        var_dump($r);
        break;
    case instanceof Maison(->moreVoiture(2) => 3, ->camion => instanceof Maison() as $r) as $result:
        var_dump($result);
        var_dump($r);
        break;
    case [1, 2, (mixed) as $third]:
        var_dump($third);
        break;
    case [...(mixed), (mixed) as $last]: 
        var_dump($last);
        break;
    default:
        break;
}
```

Explaining of the behaviours involved here:

- <code>12</code>, <code>"toto"</code> or any scalar will be check with
  <code>===</code>.
- <code>(int)</code>, <code>(string)</code> will match against a type following
  PHP rules.
- <code>(mixed)</code> is a new rule meaning everything, wildcard. Often written
  <code>_</code> in other pattern matching.
- <code>instanceof</code> will check for <code>instanceof</code> straight
  forward. It use <code>-&gt;property</code> and <code>-&gt;method()</code> to
  make a distinction between properties and methods.
- <code>...</code> is used in array to express 0 or more.
- <code>as</code> is used to introduce new variable in the code.

## The grammar

A kind of yacc grammar, terminals are indicated in quotes and r'' for regex.

```yacc
pattern:
    | scalar as_pattern
    | type as_pattern
    | 'instanceof' classname '(' object_list ')' as_pattern
    | array_pattern as_pattern
    ;

type:
    | '(bool)'
    | '(int)'
    | '(string)'
    | '(resource)'
    | '(float)' 
    | '(array)'
    | '(object)'
    | '(mixed)'
    ;

scalar:
    | r'[0-9]+' // integer
    | r'[0-9]*.[0-9]*' // float
    | r"'[^']*'"
    | r'"[^"]*"' //string
    | true
    | false
    | null
    ;

array_list:
    | pattern ',' array_list
    | pattern
    | '...' pattern ',' array_list
    | '...' pattern
    |
    ;

array_pattern:
    | 'array' '(' array_list ')'
    | '[' array_list ']'
    | 'array' '(' array_key_list ')'
    | '[' array_key_list ']'
    ;

object_list:
    | r'->[a-zA-Z0-9_]+' '=>' pattern
    | r'->[a-zA-Z0-9_]+' '(' any_php_expr ')' '=>' pattern
    ;

variable:
    | r'$[a-zA-z0-9_]+' // like $someVar
    ;

as_pattern:
    | // empty
    | 'as' variable
    ;
```

## Implementing a P.O.C.

Like <code>match</code>, a macro that spit out racket code, i will implement
this as a pre-processor that spit out valid PHP. This is not a usable solution
because it breaks line number in errors messages. i have started to write this
<abbr title="Proof Of Concept">POC</abbr> in the PHP VM (to keep correct line
number) but the whole process was slow and cumbersome
([here is the diff](/code/poc_vm.patch) that pave the basics form commit
85b9055a86 [aka PHP 7.1]). The other problem is the generate code rely on 3
globals variables and the whole thing will turn bad if you mess with them inside
a match.

Some quick glance at how this is done.

```php
<?php

match (expr) {
    case pattern: statements... break;
    default: // comme switch
}
```

Will ouput:

```php
<?php

// If there is a match before every globals variables are re-initialized.

// Used to eval expression just once.
$__MATCH__expr = expr;
// Used to store variables and populare (extract) the current scope with them
only if the whole clause match.
$__MATCH__variables = []; // of shape 'variableName' => value.
$__MATCH__result = true;

// Skeleton of any pattern clause.
$__MATCH__case0 = function ($__MATCH__expr) use (&$__MATCH__variables, &$__MATCH__result) {
    $__MATCH__inner_variables = [];
    $__MATCH__result = true;
    pattern_code;
    if ($__MATCH__result == true) {
        $__MATCH__variables = array_merge($__MATCH__variables, $__MATCH__inner_variables);
    }
    return $__MATCH__result;
}

// Use switch because match has the same behaviour of switch regarding break.
switch (true) {
  case $__MATCH__case0($__MATCH__expr):
      extract($__MATCH__variables);
      statements;
      break; // or not
}
```

Another example:

```php
<?php

// for case (int) as $someVar: var_dump($someVar); break;

$__MATCH__case2 = function ($__MATCH__expr) use (&$__MATCH__variables, &$__MATCH__result) {
    $__MATCH__inner_variables = [];
    $__MATCH__result = true;
    if ($__MATCH__result === true) {
        if (is_int($__MATCH__expr)) {
            $__MATCH__inner_variables['someVar'] = $__MATCH__expr;
        } else {
            $__MATCH__result = false;
        }
    } 
    if ($__MATCH__result === true) {
        $__MATCH__variables = array_merge($__MATCH__variables, $__MATCH__inner_variables);
    }
    return $__MATCH__result;
}

// and in the switch

// case $__MATCH__case0($__MATCH__expr):
//     extract($__MATCH__variables);
//     var_dump($someVar); break;
```

I don't go into other examples you get the idea,
see [the preprocessor](/code/matchphp.rkt)
or [an example](/code/matchphpexample.php)
and [its output](/code/matchphpexample_output.php) for more.

## Shortcomings

The above grammar misses several elements from PHP and racket match.

### There is no array key

```yacc
string_or_number:
    | r'[0-9]+' // integer
    | r'[0-9]*.[0-9]*' // float
    | r"'[^']*'"
    | r'"[^"]*"' //string
    ;
    
string_or_number_type:
    | '(int)'
    | '(string)'
    | '(mixed)'
    ;

array_list:
    | pattern ',' array_list
    | pattern
    | '...' pattern ',' array_list
    | '...' pattern
    | string_or_number => pattern ',' array_list
    | string_or_number => pattern
    | '...' string_or_number_type => pattern ',' array_list
    | '...' string_or_number_type => pattern
    |
    ;
```

### Only Scalar allowed

If general purpose PHP expression are allowed it is unclear how it will possible
to and (&& and also negating !) two clauses without adding a new keyword. The or
case is simple it just need to put several case one after the other without
break in between.

I see only 4 solution:

- Adding a new keyword like <code>&&&</code>.
- Removing expression all together.
- Removing and and not all together.
- Escape expression with something like <code>eval</code> example <code>case
  eval(1 + 1) && eval($obj->getStuff()):</code>.
  
I will bet on now for removing and and not.

### Traversable and object behaving as array

I would choose still having <code>array</code> match to check for element be an
array. And introduce a new rule like <code>'instanceof' 'Traversable' '(' array_list
')'</code>.

### Where are <code>?</code> and <code>app</code> from racket's match

For <code>?</code> it is possible to add a guard:

```php
<?php

// case (mixed) as $pattern if (is_something($pattern)):

// $pattern is implicit
// case (mixed) if (is_something($pattern)):

// even (mixed) could be implicit
// case if (is_something($pattern)):
```

Go a bit deeper into implicit <code>$pattern</code>

```php
<?php

match ([1]) {
    case [(mixed) if (var_dump($pattern) || true)] if (var_dump($pattern) || true):
}

// will print
// 1
// array(1)

// $pattern is the current part being matched.

// Ifs are executed depth first search.
```

For the <code>app</code> parts:

```php
// will match [1, 'stuff']
// the next pattern is the return value of evaluated expression.
// case [1, eval(preg*match('/stuff/', $pattern, $m)) => 1]:

// will match [1, 'stu'] but not [1, 'stuff']
// case [1, eval(preg*match('/stu(ff)?/', $pattern, $m)) use($m) => [(mixed)]]:
// use($m) subsitute $pattern value with $m's value.

// If a callable is given to eval so it is called
// case [1, eval(function ($pattern) { preg_match('/stu(ff)?/', $pattern, $m); return $m; }) => [(mixed)]]:

// because the syntax with eval could be confusing with a php expression and
// it need to add 'use', another solution is to only allow the function syntax.

// case [1, function ($pattern) { preg_match('/stu(ff)?/', $pattern, $m); return $m; } => [(mixed)]]:

// verbose but the clearer for me.
```

### Conclusion with whole hypothetical grammar

Regarding previous point here is a grammar that sum it up (contrary to the
previous one i didn't check if it didn't run into LLAR conflicts).

```yacc
pattern:
    | apply_pattern pattern_without_apply
    | pattern_without_apply
    ;

pattern_without_apply:
    | scalar as_pattern if_pattern
    | type as_pattern if_pattern
    | 'instanceof' 'Traversable' '(' array_list ')' as_pattern if_pattern
    | 'instanceof' classname '(' object_list ')' as_pattern if_pattern
    | array_pattern as_pattern if_pattern
    | php_expr as_pattern if_pattern // hope it doesn't conflict with the rest, array() for exemple
    ;

type:
    | '(bool)'
    | '(int)'
    | '(string)'
    | '(resource)'
    | '(float)' 
    | '(array)'
    | '(object)'
    | '(mixed)'
    ;

scalar:
    | r'[0-9]+' // integer
    | r'[0-9]*.[0-9]*' // float
    | r"'[^']*'"
    | r'"[^"]*"' //string
    | true
    | false
    | null
    ;

array_list:
    | pattern ',' array_list
    | pattern
    | '...' pattern ',' array_list
    | '...' pattern
    |
    ;

array_pattern:
    | 'array' '(' array_list ')'
    | '[' array_list ']'
    | 'array' '(' array_key_list ')'
    | '[' array_key_list ']'
    ;

object_list:
    | r'->[a-zA-Z0-9_]+' '=>' pattern
    | r'->[a-zA-Z0-9_]+' '(' any_php_expr ')' '=>' pattern
    ;

variable:
    | r'$[a-zA-z0-9_]+' // like $someVar
    ;

as_pattern:
    | // empty
    | 'as' variable
    ;
    
if_pattern:
    | // empty
    | 'if' '(' php_expr ')'
    ;

apply_pattern:
    | 'function' '(' variable ')' 'use' '(' stuff ')' '{' statements '}' '=>'
    ;

array_key:
    | apply_pattern php_expr as_pattern if_pattern
    | php_expr as_pattern if_pattern
    ;

array_key_ellipsis:
    | '(int)' as_pattern if_pattern 
    | '(string)' as_pattern if_pattern
    | '(mixed)' as_pattern if_pattern
    | apply_pattern pattern_without_apply
    ;

array_list:
    | pattern ',' array_list
    | pattern
    | '...' pattern ',' array_list
    | '...' pattern
    | array_key => pattern ',' array_list
    | array_key => pattern
    | '...' array_key_ellipsis => pattern ',' array_list
    | '...' array_key_ellipsis => pattern
    |
    ;
```

It add most of the feature from racket's <code>match</code> without adding any
new keyword. The missing element are <code>and</code>, <code>not</code>,
<code>regexp</code> (very easy to add with a new keyword like <code>'preg_match'
'/regex/' '=>' pattern</code>) and <code>..k</code>.

#### The whole grammar if php_expr is removed from allowed pattern

```yacc
pattern:
    | apply_pattern pattern_without_apply
    | pattern_without_apply
    ;

just_pattern:
    | variable
    | scalar 
    | type 
    | 'instanceof' 'Traversable' '(' array_list ')'
    | 'instanceof' classname '(' object_list ')'
    | array_pattern
    ;
    
pattern_without_apply:
    | just_pattern scalar as_pattern if_pattern
    | pattern '&&' pattern
    | pattern '||' pattern 
    | '(' pattern ')' as_pattern if_pattern // resolve ambiguity with as_pattern with '||' and '&&' rule.
    | pattern 'and' just_pattern as_pattern if_pattern
    | pattern 'or' just_pattern as_pattern if_pattern
    | '!' pattern
    ;

type:
    | '(bool)'
    | '(int)'
    | '(string)'
    | '(resource)'
    | '(float)' 
    | '(array)'
    | '(object)'
    | '(mixed)'
    ;

scalar:
    | '==' scalar // weak checking instead of strong one by default
    | r'[0-9]+' // integer
    | r'[0-9]*.[0-9]*' // float
    | r"'[^']*'"
    | r'"[^"]*"' //string
    | true
    | false
    | null
    ;

array_list:
    | pattern ',' array_list
    | pattern
    | '...' pattern ',' array_list
    | '...' pattern
    |
    ;

array_pattern:
    | 'array' '(' array_list ')'
    | '[' array_list ']'
    | 'array' '(' array_key_list ')'
    | '[' array_key_list ']'
    ;

object_list:
    | r'->[a-zA-Z0-9_]+' '=>' pattern
    | r'->[a-zA-Z0-9_]+' '(' any_php_expr ')' '=>' pattern
    ;

variable:
    | r'$[a-zA-z0-9_]+' // like $someVar
    ;

as_pattern:
    | // empty
    | 'as' variable
    ;
    
if_pattern:
    | // empty
    | 'if' '(' php_expr ')'
    ;

apply_pattern:
    | 'function' '(' variable ')' 'use' '(' stuff ')' '{' statements '}' '=>'
    ;

array_key:
    | apply_pattern php_expr as_pattern if_pattern
    | php_expr as_pattern if_pattern
    ;

array_key_ellipsis:
    | '(int)' as_pattern if_pattern 
    | '(string)' as_pattern if_pattern
    | '(mixed)' as_pattern if_pattern
    | apply_pattern pattern_without_apply
    ;

array_list:
    | pattern ',' array_list
    | pattern
    | '...' pattern ',' array_list
    | '...' pattern
    | array_key => pattern ',' array_list
    | array_key => pattern
    | '...' array_key_ellipsis => pattern ',' array_list
    | '...' array_key_ellipsis => pattern
    |
    ;
```

This one allow weak checking, negating pattern, and of pattern and <code>$var</code> as a shortcut for <code>(mixed) as $var</code>. 
