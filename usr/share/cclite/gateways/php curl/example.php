<?php
  $ch = curl_init("http://cclite.caca-cola.com:83/logon/dalston/manager/manager");
  curl_setopt($ch, CURLOPT_FOLLOWLOCATION, 1);
  curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
  $str = curl_exec($ch);
  if ($str !== false) {
    // do something with the content
    $str = preg_replace("/apples/", "oranges", $str);
    // avoid Cross-Site Scripting attacks
    $str = strip_tags($str);
    echo $str;
  }
  curl_close($ch);
?>
