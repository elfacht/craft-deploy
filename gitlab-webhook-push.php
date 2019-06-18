<?php
/**
 * GitLab Web Hook
 * See https://gitlab.com/kpobococ/gitlab-webhook
 *
 * This script should be placed within the web root of your desired deploy
 * location. The GitLab repository should then be configured to call it for the
 * "Push events" trigger via the Web Hooks settings page.
 *
 * Each time this script is called, it executes a hook shell script and logs all
 * output to the log file.
 *
 * This hook uses php's exec() function, so make sure it can be executed.
 * See http://php.net/manual/function.exec.php for more info
 */
// CONFIGURATION
// =============
/* Hook script location. The hook script is a simple shell script that executes
 * the actual git push. Make sure the script is either outside the web root or
 * inaccessible from the web
 *
 * This setting is REQUIRED
 */
$hookfile = './deploy.sh';
$updatefile = './update.sh';
/* Log file location. Log file has both this script's and shell script's output.
 * Make sure PHP can write to the location of the log file, otherwise no log
 * will be created!
 *
 * This setting is REQUIRED
 */
$logfile = './deploy.log';
/* Hook password. If set, this password should be passed as a GET parameter to
 * this script on every call, otherwise the hook won't be executed.
 *
 * This setting is RECOMMENDED
 */
$password = 'your-strong-webhook-password-token';
/* Ref name. This limits the hook to only execute the shell script if a push
 * event was generated for a certain ref (most commonly - a master branch).
 *
 * Can also be an array of refs:
 *
 *     $ref = array('refs/heads/master', 'refs/heads/develop');
 *
 * This setting does not support the actual refspec, so the refs should match
 * exactly.
 *
 * See http://git-scm.com/book/en/Git-Internals-The-Refspec for more info on
 * the subject of Refspec
 *
 * This setting is OPTIONAL
 */
$ref = 'refs/heads/master';
// THE ACTUAL SCRIPT
// -----------------
// You shouldn't edit beyond this point,
// unless you know what you're doing
// =====================================
function log_append($message, $time = null)
{
    global $logfile;
    $time = $time === null ? time() : $time;
    $date = date('Y-m-d H:i:s');
    $pre  = $date . ' (' . $_SERVER['REMOTE_ADDR'] . '): ';
    file_put_contents($logfile, $pre . $message . "\n", FILE_APPEND);
}
function exec_command($command)
{
    $output = array();
    exec($command, $output);
    log_append('EXEC: ' . $command);
    foreach ($output as $line) {
        log_append('SHELL: ' . $line);
    }
}
if (isset($password))
{
    if (empty($_REQUEST['p'])) {
        log_append('Missing hook password');
        die();
    }
    if ($_REQUEST['p'] !== $password) {
        log_append('Invalid hook password');
        die();
    }
}
// GitLab sends the json as raw post data
$input = file_get_contents("php://input");
$json  = json_decode($input);
if (!is_object($json) || empty($json->ref)) {
    log_append('Invalid push event data');
    die();
}
if (isset($ref))
{
    $_refs = (array) $ref;
    if ($ref !== '*' && !in_array($json->ref, $_refs)) {
        log_append('Ignoring ref ' . $json->ref);
        die();
    }
}
log_append('Launching shell hook script...');
exec_command('sh '.$hookfile);
exec_command('sh '.$updatefile);
log_append('Shell hook script finished');