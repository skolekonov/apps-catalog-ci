#!/usr/bin/python

import re
import yaml
from sys import argv
from deepdiff import DeepDiff


def yaml_to_dict(infile, k):
    stream = open(infile, 'r')
    rdict = yaml.load(stream)[k]
    return rdict


def diff_images_config(images1, images2):
    if images1 == images2:
        return

    ddiff = DeepDiff(images1, images2)
    type = ddiff.changes.keys()[0]

    if type == 'values_changed':
        changes = ddiff.changes['values_changed']
        tmp = re.search('"root\[\d\]', str(changes)).group(0)
        res_index = re.search('\d', tmp).group(0)
        res = images2[int(res_index)]
        print res['name'].replace(' ', '-').lower() + '.' + res['format'].lower()
    elif type == 'list_added':
        changes = ddiff.changes['list_added'][0]
        tmp = changes[0]
        image_name = re.search(
           '\'name\':\s\'[A-z0-9-_.\s]*\'', changes).group(0).split(' ')[1][1:-1]
        image_format = re.search(
            '\'format\':\s\'[A-z0-9]*\'', changes).group(0).split(' ')[1][1:-1]
        print image_name.replace(' ', '-').lower + '.' + image_format.lower()

if __name__ == '__main__':
    if argv[1] == 'glance':
        images1 = yaml_to_dict(argv[2], 'images')
        images2 = yaml_to_dict(argv[3], 'images')
        diff_images_config(images1, images2)
