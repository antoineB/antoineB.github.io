<?php

class Maison {
    public $voiture = 1;
    public $camion = 2;
}

function toto($a) {
    
       $__MATCH__expr = $a;
       $__MATCH__variables = [];
       $__MATCH__result = true; // usefull for nested pattern
        $__MATCH__case0 = function ($__MATCH__expr) use (&$__MATCH__variables, &$__MATCH__result) {
              $__MATCH__inner_variables = [];
              $__MATCH__result = true;
               if ($__MATCH__result === true) {
                if ($__MATCH__expr !== 12) {
                  $__MATCH__result = false;
                 }
              } 
              if ($__MATCH__result === true) {
                $__MATCH__variables = array_merge($__MATCH__variables, $__MATCH__inner_variables);
              }
                return $__MATCH__result;
           }; 
 $__MATCH__case1 = function ($__MATCH__expr) use (&$__MATCH__variables, &$__MATCH__result) {
              $__MATCH__inner_variables = [];
              $__MATCH__result = true;
               if ($__MATCH__result === true) {
                if ($__MATCH__expr !== "toto") {
                  $__MATCH__result = false;
                 }
              } 
              if ($__MATCH__result === true) {
                $__MATCH__variables = array_merge($__MATCH__variables, $__MATCH__inner_variables);
              }
                return $__MATCH__result;
           }; 
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
           }; 
 $__MATCH__case3 = function ($__MATCH__expr) use (&$__MATCH__variables, &$__MATCH__result) {
              $__MATCH__inner_variables = [];
              $__MATCH__result = true;
               if ($__MATCH__result === true) {
       if ($__MATCH__expr instanceof Maison) {
          if ($__MATCH__result === true) {
              if (isset($__MATCH__expr->{'voiture'})) {
                $__MATCH__tmp_val = $__MATCH__expr->{'voiture'}; // if it as side effect
                // function is necessary to reduce variables scope
                $__MATCH__tmp_fun = function ($__MATCH__expr) use (&$__MATCH__inner_variables, &$__MATCH__result) {
                 if ($__MATCH__result === true) {
                if ($__MATCH__expr !== 1) {
                  $__MATCH__result = false;
                 }
              } 
                };
                $__MATCH__tmp_fun($__MATCH__tmp_val);
             } else {
                 $__MATCH__result = false;
             }
           } 
 if ($__MATCH__result === true) {
              if (isset($__MATCH__expr->{'camion'})) {
                $__MATCH__tmp_val = $__MATCH__expr->{'camion'}; // if it as side effect
                // function is necessary to reduce variables scope
                $__MATCH__tmp_fun = function ($__MATCH__expr) use (&$__MATCH__inner_variables, &$__MATCH__result) {
                 if ($__MATCH__result === true) {
                if (is_int($__MATCH__expr)) {
                  $__MATCH__inner_variables['r'] = $__MATCH__expr;
                 } else {
                  $__MATCH__result = false;
                 }
              } 
                };
                $__MATCH__tmp_fun($__MATCH__tmp_val);
             } else {
                 $__MATCH__result = false;
             }
           } 
          if ($__MATCH__result === true) { $__MATCH__inner_variables['result'] = $__MATCH__expr; } 
       } else {
         $__MATCH__result = false;
       }
   } 
              if ($__MATCH__result === true) {
                $__MATCH__variables = array_merge($__MATCH__variables, $__MATCH__inner_variables);
              }
                return $__MATCH__result;
           }; 
 $__MATCH__case4 = function ($__MATCH__expr) use (&$__MATCH__variables, &$__MATCH__result) {
              $__MATCH__inner_variables = [];
              $__MATCH__result = true;
               if ($__MATCH__result === true) {
       if ($__MATCH__expr instanceof Maison) {
          if ($__MATCH__result === true) {
              if (isset($__MATCH__expr->{'voiture'})) {
                $__MATCH__tmp_val = $__MATCH__expr->{'voiture'}; // if it as side effect
                // function is necessary to reduce variables scope
                $__MATCH__tmp_fun = function ($__MATCH__expr) use (&$__MATCH__inner_variables, &$__MATCH__result) {
                 if ($__MATCH__result === true) {
                if ($__MATCH__expr !== 1) {
                  $__MATCH__result = false;
                 }
              } 
                };
                $__MATCH__tmp_fun($__MATCH__tmp_val);
             } else {
                 $__MATCH__result = false;
             }
           } 
 if ($__MATCH__result === true) {
              if (isset($__MATCH__expr->{'camion'})) {
                $__MATCH__tmp_val = $__MATCH__expr->{'camion'}; // if it as side effect
                // function is necessary to reduce variables scope
                $__MATCH__tmp_fun = function ($__MATCH__expr) use (&$__MATCH__inner_variables, &$__MATCH__result) {
                 if ($__MATCH__result === true) {
       if ($__MATCH__expr instanceof Maison) {
         
          if ($__MATCH__result === true) { $__MATCH__inner_variables['r'] = $__MATCH__expr; } 
       } else {
         $__MATCH__result = false;
       }
   } 
                };
                $__MATCH__tmp_fun($__MATCH__tmp_val);
             } else {
                 $__MATCH__result = false;
             }
           } 
          if ($__MATCH__result === true) { $__MATCH__inner_variables['result'] = $__MATCH__expr; } 
       } else {
         $__MATCH__result = false;
       }
   } 
              if ($__MATCH__result === true) {
                $__MATCH__variables = array_merge($__MATCH__variables, $__MATCH__inner_variables);
              }
                return $__MATCH__result;
           }; 
 $__MATCH__case5 = function ($__MATCH__expr) { return true; }; 
       switch (true) {
        case $__MATCH__case0($__MATCH__expr):
              extract($__MATCH__variables);
              var_dump(12); break;
 case $__MATCH__case1($__MATCH__expr):
              extract($__MATCH__variables);
              var_dump("toto"); break;
 case $__MATCH__case2($__MATCH__expr):
              extract($__MATCH__variables);
              var_dump($someVar); break;
 case $__MATCH__case3($__MATCH__expr):
              extract($__MATCH__variables);
              var_dump($result);var_dump($r);break;
 case $__MATCH__case4($__MATCH__expr):
              extract($__MATCH__variables);
              var_dump($result);var_dump($r);break;
 case $__MATCH__case5($__MATCH__expr):
              extract($__MATCH__variables);
              var_dump("default"); break;
       }
       

    return 22;
}

toto(12);
toto("toto");
toto(13);
toto(new Maison());