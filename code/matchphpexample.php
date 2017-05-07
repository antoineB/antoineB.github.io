<?php

class Maison {
    public $voiture = 1;
    public $camion = 2;
}

function toto($a) {
    match(£$a£) {
        case 12: £var_dump(12); break;£
        case "toto": £var_dump("toto"); break;£
        case (int) as $someVar: £var_dump($someVar); break;£

        case instanceof Maison(->voiture => 1, ->camion => (int) as $r) as $result:  £var_dump($result);var_dump($r);break;£
        case instanceof Maison(->voiture => 1, ->camion => instanceof Maison() as $r) as $result: £var_dump($result);var_dump($r);break;£
        default: £var_dump("default"); break;£
    }

    return 22;
}

toto(12);
toto("toto");
toto(13);
toto(new Maison());