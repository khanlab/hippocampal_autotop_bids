import setuptools

with open("README.md", "r") as fh:
    long_description = fh.read()

setuptools.setup(
    name="hippunfold", 
    version="0.1.0",
    author="Jordan DeKraker & Ali Khan",
    author_email="alik@robarts.ca",
    description="Snakemake BIDS app for hippocampal unfolding & subfield segmentation",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/khanlab/hippunfold",
    packages=setuptools.find_packages(),
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
    ],
    entry_points={'console_scripts': [
        'hippunfold=run:main'
    ]},
    install_requires=[
        "snakebids>=0.1.2",
        "pandas",
        "nibabel",
        "numpy"
    ],
    python_requires='>=3.7'
)
