# Pic2Speech - Describing the world for visually impaired

Pic2Speech uses Artificial Intelligence to describe the content of pictures to help visually impaired understanding the world.
## Model
The model is built with Keras and is mostly based on [Show and Tell: A Neural Image Caption Generator" by Vinyals et al](https://arxiv.org/pdf/1411.4555.pdf). It's trained on the Full MS COCO for around 500k steps.
## Deployment
The model is deployed on an Azure ML Service using Azure ML Python API.
## Mobile App
The mobile app is developed with Google Flutter and let people take a picture with their smartphone and get a vocal description for it.
