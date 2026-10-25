using System.Collections;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.TestTools;
using UnityBuildPipeline.Sample;

namespace UnityBuildPipeline.Tests.PlayMode
{
    public class SamplePlayModeTest
    {
        [UnityTest]
        public IEnumerator RotateObject_RotatesTransform_OverFrames()
        {
            var go = new GameObject("TestRotatingObject");
            var rotComponent = go.AddComponent<RotateObject>();
            rotComponent.RotationSpeed = new Vector3(0f, 90f, 0f);

            Quaternion initialRotation = go.transform.rotation;

            // Wait for 3 frames
            yield return null;
            yield return null;
            yield return null;

            Quaternion finalRotation = go.transform.rotation;
            Assert.AreNotEqual(initialRotation, finalRotation, "Transform should have rotated after multiple frames.");

            Object.Destroy(go);
            yield return null;
        }
    }
}
