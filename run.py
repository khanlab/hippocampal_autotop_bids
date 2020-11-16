#!/usr/bin/env python3
import os
from snakebids.app import SnakeBidsApp


def main():

    pwd = os.path.abspath(os.path.dirname(__file__))
    app = SnakeBidsApp(pwd)
    app.run_snakemake()


if __name__ == "__main__":
    main()
