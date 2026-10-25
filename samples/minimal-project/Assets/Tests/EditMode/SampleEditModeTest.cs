using NUnit.Framework;

namespace UnityBuildPipeline.Tests.EditMode
{
    [TestFixture]
    public class SampleEditModeTest
    {
        [Test]
        public void Mathematics_Addition_EvaluatesCorrectly()
        {
            const int a = 20;
            const int b = 22;
            const int expected = 42;

            Assert.AreEqual(expected, a + b, "Expected 20 + 22 to equal 42.");
        }

        [Test]
        public void VersionString_SemanticPattern_IsValid()
        {
            const string version = "2022.3.48f1";
            StringAssert.Contains("2022.3", version, "Unity version string should match LTS branch.");
        }
    }
}
