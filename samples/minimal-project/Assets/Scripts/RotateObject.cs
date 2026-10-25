using UnityEngine;

namespace UnityBuildPipeline.Sample
{
    /// <summary>
    /// Sample MonoBehaviour that rotates a GameObject smoothly per frame.
    /// Used for basic PlayMode test verification.
    /// </summary>
    public class RotateObject : MonoBehaviour
    {
        [SerializeField]
        private Vector3 rotationSpeed = new Vector3(15f, 30f, 45f);

        public Vector3 RotationSpeed
        {
            get => rotationSpeed;
            set => rotationSpeed = value;
        }

        private void Update()
        {
            transform.Rotate(rotationSpeed * Time.deltaTime);
        }
    }
}
