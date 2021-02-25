import os
import tempfile


def test_single_t1w(script_runner):
    os.environ['HIPPUNFOLD_CACHE_DIR'] = os.path.join(os.getcwd(),'test_data/fake_models')
    with tempfile.TemporaryDirectory() as output_dir:
        print('created temporary directory', output_dir)
        ret = script_runner.run('hippunfold', 'test_data/bids_singleT2w',output_dir,'participant','-np')
        assert ret.success
#    assert ret.stdout == '3.2.1\n'
#    assert ret.stderr == ''
