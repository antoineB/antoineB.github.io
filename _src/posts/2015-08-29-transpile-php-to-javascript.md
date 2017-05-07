    Title: transpile php to javascript
    Date: 2015-08-29T17:27:34
    Tags: php,javascript

<p class="lead"> Some ideas on how to build a php to javascript transpiler </p>

<br/>

I spend a good part of my work time in front of php or javascript code, so i
wonder what will it be to compile php to javascript (in a browser context
only). All of this is not tested it is just out of my head, i should have looked up
how other have come up with problems like <code>yield</code> but this would kill
all interest.

<!-- more -->

Just some specifications of the top level definition that will be used through
all the post:

```javascript
// php functions (indexed by full qualified name)
window.PHPFunction = {};
// constructors as js function
window.PHPConstructor = {};
// all the class indexed by full qualified name
window.PHPClass = {};
// all the rest of the stuff, type constructor, type cast function, etc...
window.PHP = {};
```

# Types

PHP type to javascript

1. string -> js string
2. float -> a new class PHP.Float
3. integer -> js number
4. bool -> bool
5. null -> null
6. undefined -> undefined
7. unassigned -> a singleton of a class PHP.UnAssigned
8. array -> a new class PHP.Array
9. object -> a javascript object instance of PHP.Object

There is no much thought to put into those choices maybe a wiser will try to have the
maximum matching behavior between php <code>==</code>, <code>===</code> and js
counter parts or other strategies to reduce the overhead of type checking.

The array in PHP is not just an array as you know so it can't be mapped directly
to the vanilla js Array class. For now the easy way is to define a specific
class to handle all the case (hash table, local index change etc...).

Continuing with the number it's necessary to introduce at least one new class to
distinguish from Number the integer and the float.

Giving us something like:

```javascript
PHP = (function () {
    var UnAssigned = function () {};
    var UNASSIGNED = new UnAssigned;
    var Float = function (value) { this.value = value; };
    var Array = function () {};
    var Object = function () {};
    
    return {
        UNASSIGNED: UNASSIGNED,
        gettype: function (obj) {
            var type = typeof obj;
            if (type == 'string') {
                return 'string';
            }
            if (type == 'number') {
                return 'integer'
            }
            if (type == 'boolean') {
                return 'boolean';
            }
            if (obj instanceof Array) {
                return 'array';
            }
            if (obj instanceof Float) {
                return 'double';
            }
            if (obj instanceof Object) {
                return 'object';
            }
            if (obj === undefined || obj === null || obj === UNASSIGNED) {
                return null;
            }
            throw new String('hope it never happen');
        },
        js_to_php: function (obj) {
            if (obj instanceof window.Object) {
                if (obj instanceof window.String) {
                    return obj;
                }
                if (obj instanceof window.Array) {
                    return new PHP.Array(obj);
                }
                if (obj instanceof window.Number) {
                    if (window.Number.isInteger(obj)) {
                        return obj;
                    }
                    return new Float(obj);
                }
                return PHP.Object(obj);
            }
            if (obj == null || obj == undefined) {
                return obj;
            }
            var type = typeof obj;
            if (type == 'number') {
                if (window.Number.isInteger(obj)) {
                    return new window.Number(obj);
                }
                return new Float(obj);
            }
            if (type == 'string') {
                return new window.String(obj);
            }
            if (type == 'boolean') {
                return obj;
            }
            throw new String('hope it never happen');
        },
        // return a friendly datastructure from the point of view of javascript
        php_to_js: function (obj) {
            if (obj instanceof Float) {
                return Float.value;
            }
            if (obj === UNASSIGNED) {
                return undefined;
            }
            if (obj instanceof PHP.Array) {
                // convert hash table into a json
                // a window.Array otherwise
            }
            if (obj instanceof PHP.Object) {
                // return a json with public property and classname
            }
            // string, int, null, undefined, bool, array
            return obj;
        }
};
```

Maybe using the vanilla Array to treat the case where the array is actually an
array indexed by ℕ⁰ with internal array pointer to 0 and expect a minor speedup.

```javascript
var PHPArray = function () {
    // init
};

PHPArray.prototype = Object.create(Array.prototype);
```

## Casting

This should be carefully done according to the php
[docs](http://php.net/manual/en/types.comparisons.php), the <code>(bool)</code>
operator as an example:

```javascript
PHP.cast_bool = function (obj) {
  if (obj === false) {
      return false;
  }
  if (obj === '' || obj === '0') {
      return false;
  }
  if (obj === null) {
  return false;
  }
  if (obj === undefined) {
      return false;
  }
  if (obj === 0) {
      return false;
  }
  if (obj instanceof UNASSIGNED) {
      return false;
  }
  if (obj instanceof PHP.Array && PHP.empty(obj)) {
      return false;
  }
  return true;
  }
};
```

# Mapping variable name

The mapping between php and javascript of variable could be direct for instance
if you declare a <code>$abc = 12</code> the js will be <code>var abc =
Number(12)</code>.

But there is two exception <code>get_defined_vars()</code> and
<code>extract()</code> to please them both its necessary to use a js object to
get track of variables and populate them directly.

```php
<?php

function abc() {
  $a = 12;
  extract(['b' => 12]);
  get_defined_vars();
  return someFun($a);
}
```

```javascript
PHPFunction.abc = function() {
  var state = {};
  PHP.states.push(state);
  state.a = 12;
  // extract and get_defined_vars will lookup into PHP.states[PHP.states.length - 1]
  PHPFunction.extract(PHP.array({'b' => 12});
  PHPFunction.get_defined_vars();
  var result = PHPFunction.someFun(state.a);
  PHP.states.pop();
  return result;
};
```

The <code>PHP.states[0]</code> correspond to the globals
variables. <code>PHP.states</code> is necessary because
<code>get_defined_vars</code> and <code>extract</code> could be call dynamicaly
and will always be able to reference the states they relate two with
<code>PHP.states[PHP.states.length - 1]</code>.


For the rest of the code example i will use a direct mapping for readability.

## optimization

If it can be proved that the current function code didn't call
<code>extract</code> nor <code>get_defined_vars</code> then a direct mapping
could be used instead.

<code>PHP.states[PHP.states.length - 1]</code> may be slower than
<code>PHP.states[0]</code> so the latter convention sould be used where
<code>0</code> denote the current state and
<code>PHP.states[PHP.states.length - 1]</code> the globals.

# Class

A class like:

```php
<?php

class Abc interface A, B extends Edf {
    public $publicProp;
    private $privateProp;
    protected $protectedProp;

    public function __constructor($abc) { $this->private = 2; }
    public function publicMeth() { }
    private function privateMeth() { }
    protected function protectedMeth() { }
}

$instance = new Abc(3);
```

Translate to:

```javascript
PHPClass.Abc = {
    interface: [PHPClass.A, PHPCLass.B],
    extends PHPClass.Edf,
    private_method: {
        privateMeth: function () {}
    },
    public_method: {
        publicMeth: function () {}
    },
    protected_method: {
        protectedMeth: function () {}
    },
    destruct: null,
    statics: {},
    consts: {},
    doc_comments: {},
    invoke: null,
    __call: null,
    __set: null,
    __get: null,
    // other magic method
};

PHPConstructorBasic = false;

PHPConstructor.Abc = function () {
    this.public.publicProp = PHP.UNASSIGNED; // singleton
    this.protected.protectedProp = 1;
    this.private.privateProp = PHP.UNASSIGNED;
    this.meta = PHPClass.Abc;
    this.extends = null;

    PHPConstructorBasic = true;
    this.extends = new PHPConstructor.Edf();
    PHPConstructorBasic = false;

     if (PHPConstructorBasic !== true) {
        var abc = arguments[0];
        PHP.object_assign_property(this, this, 'privateProp', 2);
    }
};

PHPConstructor.Abc.prototype = Object.create(PHPConstructor.Edf.prototype);

PHPConstructor.Edf.prototype = Object.create(PHP.Object.prototype);

var instance = new PHPConstructor.Abc(3);
```

So a php class is divided into two parts the part that contain the methods
definitions, interfaces and the like. Another part wich is the constructor of an
instance which contain the properties, the class which is the instance of (with
meta) and its parent instance, the scope of property is needed to be done
explicitly by lack of scope in javascript.

The constructor is composed of two parts the first that create the properties,
assign their default value and call the save part of the constructor on the
parent. The second is the user defined <code>__constructor</code> code. The
parent constructor should be call explicitly in php so that why there is the
variable PHPConstructorBasic.

Because i didn't use the javascript inheritance i need to wrap every use of <code>-></code>
with a function. The fact i put <code>this</code> twice is not a mistake it's the current
instance, it's seems silly in that example, but usefull when you do <code>$someVar =
$this; $someVar->privateThing</code>. And then simulate the inheritance in the code in
object_assign_property something like:

```javascript
var object_assign_property = (function () {
    var assign = function (instance, propertyName, value) {
        if (instance.public[propertyName] !== undefined) {
            instance.public[propertyName] = value;
            return;
        }
        if (instance.protected[propertyName] !== undefined) {
            instance.protected[propertyName] = value;
            return;
        }
        if (instance.private[propertyName] !== undefined) {
            instance.private[propertyName] = value;
            return;
        }
        if (instance.extends === null) {
            throw new Exception('no property ' + propertyName);
        }
        assign(instance.extends, propertyName, value);
    };
    
    var assignPublic = function (instance, propertyName, value) {
        if (instance.public[propertyName] === undefined) {
            if (instance.extends !== null) {
                assignPublic(instance.extends, propertyName, value);
            } else {
                throw new Exception('no property ' + propertyName);
            }
        }
        instance.public[propertyName] = value;
    };
    
    return function (context, instance, propertyName, value) {
        if (context == instance) {
            assign(instance, propertyName, value);
        } else {
            assignPublic(instance, propertyName, value);
        }
    };
    })();
```

And method call:

```javascript
var object_method_call = (function () {
    var callMeth = function (instance, methodName, args) {
        if (instance.meta.public[methodName] !== undefined) {
            return instance.meta.public[methodName].apply(instance, args);
        }
        if (instance.protected[methodName] !== undefined) {
            return instance.meta.protected[methodName].apply(instance, args);
        }
        if (instance.private[methodName] !== undefined) {
            return instance.meta.private[methodName].apply(instance, args);
        }
        if (instance.extends === null) {
            throw new Exception('no method ' + methodName);
        }
        callMeth(instance.extends, methodName, args);
    };
    
    var callMethPublic = function (instance, methodName, value, args) {
        if (instance.meta.public[methodName] === undefined) {
            if (instance.extends !== null) {
                callMethPublic(instance.extends, methodName, args);
            } else {
                throw new Exception('no method ' + methodName);
            }
        }
        instance.meta.public[methodName].apply(instance, args);
    };
    
    return function (context, instance, methodName, args) {
        if (context == instance) {
            callMeth(instance, methodName, args);
        } else {
            callMethPublic(instance, methodName, args);
        }
    };
    })();
```

## Magic method

There is nothing to say, because every object access is wrap into a function the
logic for magic method (<code>__get</code>, <code>__set</code>,
<code>__call</code>) could be added here.

For the rest the logic happen in other function.

## Type hinting

Just add the check where relevant.

## Self, static and parent

Assume in class Abc, then:

1. <code>self</code> translate to <code>PHPClass.Abc</code>
2. <code>parent</code> translate to <code>PHPClass.Abc.extend</code>
3. <code>static</code> translate to <code>this.meta</code>

## Class definition correctness

The check if a given class implement its interface's methods or not is checked at
compile time, so no javascript involved.

## Optimization

If it can proved which method will be call then the
<code>object_method_call</code> become useless and the direct access to the
function can be used, and this could be done a lot.

# Exception and errors

```php
<?php

try {}
catch(Abc $a) {}
catch(Edf $e) {}
finally {}
```

```javascript
try {}
catch(e) {
  if (e instanceof PHPConstructor.Abc) {}
  if (e instanceof PHPConstructor.Edf) {}
  finallyCode()
}
```

For the <code>set_exception_handler</code> the complete generate code need to be
wrapped inside a try that catch on PHP.Exception and apply handler if there
is. By the way <code>exit()</code> and <code>die()</code> will be implemented
respectively with <code>throw new PHP.Exit()</code> and <code>throw new
PHP.Die()</code>.

For errors this is different because errors don't stop the execution of the code, i
don't know all the cases where error happen but the only one i see demanding
extra work is the access to an undefined variable.

```php
echo $a;
```

```javascript
// keep in mind that like javascript php hoist its variables, so scan the code,
// find all variable, declare them all with UNASSIGNED
var a = PHP.UNASSIGNED;
PHP.echo((function () { if (a === PHP.UNASSIGNED) { PHP.error = 'undefined $a'; return PHP.null; } else { return a;}})());
```

# Other statements

## Instanceof

```javascript
// full qualified class name, namespace are a
// compile time thing in php
PHP.instanceof = function (obj, class) {
   var fn;
   fn = function (meta) {
       if (meta == PHPCLASS[class]) {
           return true;
       }
       if (meta.extends === null) {
           return false;
       }
       return fn(meta.extends);
   };
   if (obj instanceof PHP.Object) {
       return fn(obj.meta);
   }
   return false;
};
```

## If and while

```php
<?php

if ($expr) {}
```

Transpile to:

```javascript
if (PHP.to_bool(expr)) {}
```

# Yield

Assume a funcion like so:

```php
<?php

function fn() {
    $a = 1;
    $a++;
    yield $a;
    $a++;
    yield $a;
    $a++;
    yield $a;
}
```

The yield can be seen as a function that return at yield, and when call later
will not start from the begining of the function but from the last used yield.
And also have the same state from last call.

```javascript
PHPFunction.fn = function () {
return new PHP.Generator(function () {
    var position = 0;
    var a;

    var codes = [
        function () {
            // all the code for remove complexity in code analysis
            a = 1;
            a++;
            position = 0;
            return a;
            a++;
            position = 1;
            return a;
            a++;
            position = 2;
            return a;
        },
        function () {
            a++;
            position = 1;
            return a;
            a++;
            position = 2;
            return a;
        },
        function () {
            a++;
            position = 2;
            return a;
        }
    ];
    var end = false;
    
    return function () {
        if (end) return ;
        var result = codes[position].apply(this, arguments);
        end = (codes.length - 1) >= position;
        return result;
    };
}();
```

But what happen when we put a yield inside a loop:

```php
<?php

function fn($datas) {
    stuffA();
    foreach ($datas as $data) {
        stuffB();
        yield $data;
        stuffC();
    }
    stuffD();
}
```

This one is more hard, transform the foreach into a goto:

```php
<?php

function fn($datas) {
    stuffA();
    $i = 0;
    begin_loop:
    if (isset($datas[$i])) {
        goto end_loop;
    }
    $data = $datas[$i];
    stuffB();
    yield $data;
    stuffC();
    $i++;
    goto begin_loop;
    end_loop:
    stuffD();
}
```

just convert the goto, but let the yield untreated.

```javascript
PHP.Goto = function (name) {
    this.name = name;
};

var PHPFunction.fn = function (datas) {
return new PHP.Generator(function () {
    var that;
    var position = 0;

    var i;
    var data;
    
    var gotos = {
        'begin_loop': function () {
            if (PHP.isset(datas, i)) {
                return new PHP.Goto('end_loop');
            }
            data = PHP.array_access(datas, i);
            PHPFunction.stuffB();
            yield $data;
            PHPFunction.stuffC();
            i++;
            return new PHP.Goto('begin_loop');
            PHPFunction.stuffD();
        },
        'end_loop': function () {
            PHPFunction.stuffD();
        }
    };
        
    
    return function () {
        var trampoline = function () {
            PHPFunction.stuffA();
            i = 0;
            if (PHP.isset(datas, i)) {
                return new PHP.Goto('end_loop');
            }
            data = PHP.array_access(datas, i);
            PHPFunction.stuffB();
            yield $data;
            PHPFunction.stuffC();
            i++;
            return new PHP.Goto('begin_loop');
            PHPFunction.stuffD();
        };

        var go = true;
        do {
            trampoline = trampoline.call(that);
            if (trampoline instanceof PHP.Goto) {
                trampoline = gotos[trampoline.name];
            } else {
                go = false;
            }
        } while (go);

        return trampoline;
    };
})();
```

Without the yield:

```javascript

PHP.Goto = function (name) {
    this.name = name;
};

var PHPFunction.fn = function (datas) {
    return new PHP.Generator(function () {
        var that;
        var position = 0;

        var i;
        var data;
        
        var gotos = {
            'begin_loop': function () {
                if (PHP.isset(datas, i)) {
                    return new PHP.Goto('end_loop');
                }
                data = PHP.array_access(datas, i);
                PHPFunction.stuffB();
                return data;
                PHPFunction.stuffC();
                i++;
                return new PHP.Goto('begin_loop');
                PHPFunction.stuffD();
            },
            'end_loop': function () {
                PHPFunction.stuffD();
            }
        };

        var codes = [
            function () {
                PHPFunction.stuffA();
                i = 0;
                if (PHP.isset(datas, i)) {
                    return new PHP.Goto('end_loop');
                }
                data = PHP.array_access(datas, i);
                PHPFunction.stuffB();
                position = 1;
                return new data;
                PHPFunction.stuffC();
                i++;
                return new PHP.Goto('begin_loop');
                PHPFunction.stuffD();
            },
            function () {
                PHPFunction.stuffC();
                i++;
                return new PHP.Goto('begin_loop');
                PHPFunction.stuffD();
            }
        ];
        
        return function () {
            var trampoline = codes[position];

            var go = true;
            do {
                trampoline = trampoline.call(that);
                if (trampoline instanceof PHP.Goto) {
                    trampoline = gotos[trampoline.name];
                } else {
                    go = false;
                }
            } while (go);

            return trampoline;
        };
    });
};
```

# Passing arguments by address

Wrap every arguments inside a Box for every call you can't infer the signature
of the function.

```php
<?php

$a = array();
end($a);
```

```javascript
var PHP.Box = function (value) {
  this.value = value;
};
```

```javascript
var a = PHP.array();
var a_box = new PHP.Box(a);
PHPFunction.end(a_box);
a = a_box.value;
```

Heavy.

## Unset

Easy PHP.UNASSIGNED is for.

# Don't took into account

1. Foreach
2. Break and continue
3. Anonymous Class
4. Autoload
5. Tick
6. Object reflection
7. Closure syntax
8. Resources
9. Trait (but a pure compile time mechanic)
10. Namespace (also a pure compile time mechanic)

And more.

# Conclusion

It's more complex than i would have thought in the first place. Minification seems
to be feasible only on white space and on few PHP.{} name definition. The dead
code elimination is impossible if the used function can't be infered from a static
analysis (use <code>call_user_function<code> or <code>$this->{$expr}()</code>
will forbid optimization) of the code is used, that will lead to heavy weight file. The
constant need to convert thing in and out could also greatly decrease the
performances and can't be easily optimized like method calls.



