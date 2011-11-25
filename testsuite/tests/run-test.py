#!/usr/bin/env python
"""Usage: run-test [options] test_dir

Run a test located in test_dir
"""

from gnatpython.fileutils import get_rlimit
from gnatpython.main import Main
from gnatpython.testdriver import TestRunner, add_run_test_options

import os
import sys


class TestPolyORB(TestRunner):

    def __init__(self, *args, **kwargs):
        TestRunner.__init__(self, *args, **kwargs)
        if not os.path.isfile(self.test + '/test.cmd'):
            if os.path.isfile(self.test + '/test.py'):
                self.opt_results['CMD'] = 'test.py'
            elif os.path.isfile(self.test + '/test.sh'):
                self.opt_results['CMD'] = 'test.sh'

    def compute_cmd_line(self, filesize_limit=36000):
        """Compute command line

        Increase maximum execution time (the original max execution time is
        used by the test to run the server process, wait 10 more seconds to
        allow the server process to be killed).
        """
        # Pass original max execution time to the test
        os.environ["RLIMIT"] = self.opt_results['RLIMIT']
        os.environ["TEST_NAME"] = self.test

        # And add 10 more seconds for rlimit
        self.opt_results["RLIMIT"] = str(int(self.opt_results['RLIMIT']) + 10)

        # Find which script language is used. The default is to consider it
        # in Windows CMD format.
        _, ext = os.path.splitext(self.opt_results['CMD'])
        if ext in ['.cmd', '.sh', '.py']:
            cmd_type = ext[1:]
        else:
            cmd_type = 'cmd'

        # Compute command line
        rlimit = get_rlimit()
        assert rlimit, 'rlimit not found'
        self.cmd_line = [rlimit, self.opt_results['RLIMIT']]

        if cmd_type == 'sh':
            self.compute_cmd_line_sh(filesize_limit, 'bash')
        if cmd_type == 'py':
            self.compute_cmd_line_py(filesize_limit)
        elif cmd_type == 'cmd':
            self.compute_cmd_line_cmd(filesize_limit)

    def compute_cmd_line_sh(self, filesize_limit, shell):
        """Compute self.cmd_line and preprocess the test script

        REMARKS
          This function is called by compute_cmd_line
        """
        self.cmd_line += [shell, self.opt_results['CMD']]
        if self.test_args:
            self.cmd_line += self.test_args

    def apply_output_filter(self, str_list):
        """Check that at least a server or local test has passed

        Failed if test_utils.fail() has been called ("TEST FAILED" written)
        """
        if str_list and 'TEST FAILED' in str_list:
            return str_list
        if 'server PASSED' in str_list or 'local PASSED' in str_list:
            # Test ok
            return []
        else:
            # No PASSED !
            return str_list


def main():
    """Run a test"""
    m = Main(add_targets_options=True)
    add_run_test_options(m)
    m.parse_args()
    if not m.args:
        sys.exit("Error: 1 argument expected. See -h")

    if m.options.restricted_discs is not None:
        m.options.restricted_discs = m.options.restricted_discs.split(',')
    t = TestPolyORB(
        m.args[0],
        m.options.discs,
        m.options.output_dir,
        m.options.tmp,
        m.options.enable_cleanup,
        m.options.restricted_discs,
        len(m.args) > 1 and m.args[1:] or None,
        m.options.failed_only,
        m.options.timeout)

    t.execute()


if __name__ == '__main__':
    main()
