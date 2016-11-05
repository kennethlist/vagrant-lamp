<?php
$result = mail('mail@test.dev', 'Feedback', 'This is so useful, thanks!');
if($result){
    echo "Mail Sent!";
}
?>