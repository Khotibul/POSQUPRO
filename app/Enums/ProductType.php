<?php

namespace App\Enums;

enum ProductType: string
{
    case RawMaterial = 'raw_material';
    case FinishedGoods = 'finished_goods';
    case Service = 'service';
}
